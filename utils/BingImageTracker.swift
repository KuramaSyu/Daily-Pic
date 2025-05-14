import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers


actor DownloadLock {
    private var isDownloading = false

    func tryLock() -> Bool {
        guard !isDownloading else { return false }
        isDownloading = true
        return true
    }

    func unlock() {
        isDownloading = false
    }
}

class BingImageTrackerView: ImageTrackerViewProtocol {
    
    func reloadImages() async {
        print("update images")
        await MainActor.run {
            GalleryViewModel.shared.loadImages()
        }
    }
    
    func setImageReveal(date: Date) async {
        await MainActor.run {
            if GalleryViewModel.shared.revealNextImage != nil {
                return
            }
            print("Reveal from BingImageTracker")
            let revealNextImage = RevealNextImageViewModel.new(date: date)
            GalleryViewModel.shared.revealNextImage = revealNextImage
        }
    }
    
    func setImageRevealMessage(message: String) async {
        await MainActor.run {
            GalleryViewModel.shared.revealNextImage?.viewInfoMessage = message
        }
    }
}

/// BingImageTracker tracks by checking the filesystem which images and dates exist. Then it downloads missing
/// images via the BingWallpaperAPI
class BingImageTracker: ImageTrackerProtocol {
    static let shared = BingImageTracker(
        folderPath: GalleryModel.shared.folderPath,
        metadataPath: GalleryModel.shared.metadataPath,
        bingWallpaper: BingWallpaperAPI.shared
    )
    let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ImageDownloader", category: "Image Tracker")
    private let folderPath: URL
    private let metadataPath: URL
    private let bingWallpaper: BingWallpaperAPI
    private var isDownloading = false // Tracks whether a download is in progress
    private let downloadLock = DownloadLock()
    private let view = BingImageTrackerView();

    init(folderPath: URL, metadataPath: URL, bingWallpaper: BingWallpaperAPI) {
        self.folderPath = folderPath
        self.metadataPath = metadataPath
        self.bingWallpaper = bingWallpaper
    }

    func getMissingDates() -> [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = Date()
        var daysToAdd: [Date] = []
        var missingDates: [Date] = []

        for i in 0..<15 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                daysToAdd.append(calendar.startOfDay(for: date))
            }
        }

        let images = GalleryViewModel.shared.getItems()
        let existingDates = Set(images.map { $0.getDate() })
        for date in daysToAdd {
            if !existingDates.contains(date) {
                missingDates.append(date)
            }
        }
        return missingDates
    }

    
    /// determines whether a ui update is needed. This is determined by
    /// the dates if these contain today
    private func needs_ui_update(dates: [Date]) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        if dates.contains(today) {
            return true
        }
        return false
    }
    
    private func get_today() -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.startOfDay(for: Date())
    }
    
    
    func downloadMissingImages(from dates: [Date]? = nil, reloadImages: Bool = false) async -> [Date] {
        // Use the DownloadLock to ensure only one execution at a time
        guard await downloadLock.tryLock() else {
            log.warning("Download operation already in progress.")
            return []
        }
        defer { Task { await downloadLock.unlock() } }
        if isDownloading {
            log.warning("Download operation already in progress.")
            return []
        }
        
        if let reveal = GalleryViewModel.shared.revealNextImage {
            await reveal.removeIfOverdue()
        }
        
        if GalleryViewModel.shared.revealNextImage != nil {
            log.debug("Seems like image reveal is sheduled")
            return []
        }
        
        isDownloading = true
        defer { isDownloading = false } // Reset state when done
        
        // update images of manager
        if reloadImages {
            log.info("update images")
            await MainActor.run {
                GalleryViewModel.shared.loadImages()
            }
        }

        let missingDates: [Date] = dates ?? getMissingDates()
        if missingDates.isEmpty {
            log.debug("Seems like there are no images to download")
            return []
        }
        var downloadedDates: [Date] = []
        
        await self.view.setImageReveal(date: self.get_today())
        await self.view.setImageRevealMessage(message: "Downloading Images")
        
        // async fetch all images
        await withTaskGroup(of: (Date, Bool).self) { group in
            for date in missingDates {
                group.addTask {
                    do {
                        try await self.downloadImageWithTimeout(of: date)
                        self.log.debug("finished a download")
                        return (date, true)
                    } catch {
                        self.log.error("Error downloading image for date \(date): \(error.localizedDescription)")
                        await GalleryViewModel.shared.revealNextImage?.deleteTrigger()
                        return (date, false)
                    }
                }
            }
            
            self.log.debug("collecting image download results")
            for await (date, success) in group {
                if success {
                    downloadedDates.append(date)
                }
            }
        }
        Task { await GalleryViewModel.shared.revealNextImage?.startTrigger() }
        await self.view.setImageRevealMessage(message: "next image ready")

        return downloadedDates
    }

    private func downloadImageWithTimeout(of date: Date) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the download task
            group.addTask {
                try await self.downloadImage(of: date)
            }
            
            // Add the timeout task
            group.addTask {
                let totalDuration: UInt64 = 3 * 60 * 1_000_000_000 // 3 minutes
                let interval: UInt64 = 100_000_000 // 100ms interval
                var elapsed: UInt64 = 0

                while elapsed < totalDuration {
                    try Task.checkCancellation() // Check for cancellation
                    try await Task.sleep(nanoseconds: interval)
                    elapsed += interval
                }

                throw ImageDownloadError.imageDownloadFailed
            }

            do {
                log.debug("waiting for a task in downloadImageWithTimeout")
                try await group.next() // Wait for the first task to complete
                log.debug("one task in downloadImageWithTimeout completed")
            } catch {
                log.error("\(#function): error: \(error)")
                throw error
            }

            // Cancel remaining tasks
            group.cancelAll()
            log.debug("other task in downloadImageWithTimeout cancelled")
        }
    }




    private func downloadImage(of date: Date, updateUI: Bool = true) async throws {
        log.info("Starting image download for date: \(date)")

        guard let jpg_metadata = (await bingWallpaper.downloadImage(of: date))?.images.first else {
            log.error("Failed to download image data from Bing")
            throw ImageDownloadError.imageDownloadFailed
        }

        let imageURL = jpg_metadata.getImageURL()
        var image = try await createNSImage(from: imageURL)
        
        // Ensure image is freed at function exit
        defer { image = nil }
                    
        guard let valid_image = image else {
            log.error("Failed to create NSImage from URL: \(imageURL)")
            throw ImageDownloadError.imageCreationFailed
        }

        let imagePath = folderPath.appendingPathComponent(jpg_metadata.getImageName())

        do {
            let worked = try await saveImage(valid_image, to: imagePath)
            guard worked else {
                log.error("Failed to save image to: \(imagePath)")
                throw ImageDownloadError.imageSaveFailed
            }
            log.info("Successfully saved image to: \(imagePath)")
        } catch {
            log.error("Error saving image: \(error.localizedDescription)")
            throw ImageDownloadError.imageSaveFailed
        }

        do {
            try await jpg_metadata.saveFile(to_dir: metadataPath)
            log.info("Successfully saved metadata")
        } catch {
            log.error("Failed to save metadata: \(error.localizedDescription)")
            throw ImageDownloadError.metadataSaveFailed
        }
    }

    private func createNSImage(from url: URL) async throws -> NSImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return NSImage(data: data)
    }

    private func saveImage(_ image: NSImage, to path: URL, as format: NSBitmapImageRep.FileType = .jpeg) async throws -> Bool {
        return try await Task.detached(priority: .userInitiated) {
            guard let tiffData = image.tiffRepresentation else {
                return false
            }

            guard let imageRep = NSBitmapImageRep(data: tiffData) else {
                return false
            }

            guard let imageData = imageRep.representation(using: format, properties: [:]) else {
                return false
            }

            try imageData.write(to: path)
            return true
        }.value
    }
}
