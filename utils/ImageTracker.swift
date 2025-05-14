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

class BingImageTrackerView {
    
}

/// BingImageTracker tracks by checking the filesystem which images and dates exist. Then it downloads missing
/// images via the BingWallpaperAPI
class BingImageTracker {
    static let shared = BingImageTracker(
        folderPath: GalleryModel.shared.folderPath,
        metadataPath: GalleryModel.shared.metadataPath,
        bingWallpaper: BingWallpaperAPI.shared
    )
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ImageDownloader", category: "ImageDownload")
    private let folderPath: URL
    private let metadataPath: URL
    private let bingWallpaper: BingWallpaperAPI
    private var isDownloading = false // Tracks whether a download is in progress
    private let downloadLock = DownloadLock()

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

    private func setImageReveal() async {
        await MainActor.run {
            if GalleryViewModel.shared.revealNextImage != nil {
                return
            }
            print("Reveal from BingImageTracker")
            let revealNextImage = RevealNextImageViewModel.new(date: get_today())
            GalleryViewModel.shared.revealNextImage = revealNextImage
        }
    }
    
    private func setImageRevealMessage(message: String?) async {
        await MainActor.run {
            GalleryViewModel.shared.revealNextImage?.viewInfoMessage = message
        }
    }
    
    // determines whether a ui update is needed. This is determined by
    // the dates if these contain today
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
    
    
    func downloadMissingImages(from dates: [Date]? = nil, realoadImages: Bool = false) async -> [Date] {
        // Use the DownloadLock to ensure only one execution at a time
        guard await downloadLock.tryLock() else {
            logger.warning("Download operation already in progress.")
            return []
        }
        defer { Task { await downloadLock.unlock() } }
        if isDownloading {
            logger.warning("Download operation already in progress.")
            return []
        }
        
        if let reveal = GalleryViewModel.shared.revealNextImage {
            await reveal.removeIfOverdue()
        }
        
        if GalleryViewModel.shared.revealNextImage != nil {
            print("Seems like image reveal is sheduled")
            return []
        }
        
        isDownloading = true
        defer { isDownloading = false } // Reset state when done
        
        // update images of manager
        if realoadImages {
            print("update images")
            await MainActor.run {
                GalleryViewModel.shared.loadImages()
            }
        }

        let missingDates: [Date] = dates ?? getMissingDates()
        if missingDates.isEmpty {
            print("Seems like there are no images to download")
            return []
        }
        var downloadedDates: [Date] = []
        
        await self.setImageReveal()
        await self.setImageRevealMessage(message: "Downloading Images")
        await withTaskGroup(of: (Date, Bool).self) { group in
            for date in missingDates {
                group.addTask {
                    do {
                        try await self.downloadImageWithTimeout(of: date)
                        print("finished a download")
                        return (date, true)
                    } catch {
                        self.logger.error("Error downloading image for date \(date): \(error.localizedDescription)")
                        await GalleryViewModel.shared.revealNextImage?.deleteTrigger()
                        return (date, false)
                    }
                }
            }
            
            print("for loop entering in downloadMissingImages")
            for await (date, success) in group {
                if success {
                    downloadedDates.append(date)
                }
            }
        }
        Task { await GalleryViewModel.shared.revealNextImage?.startTrigger() }
        await self.setImageRevealMessage(message: "next image ready")

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
                print("waiting for a task in downloadImageWithTimeout")
                try await group.next() // Wait for the first task to complete
                print("one task in downloadImageWithTimeout completed")
            } catch {
                print("in catch block of downloadImageWithTimeout")
                throw error
            }

            // Cancel remaining tasks
            group.cancelAll()
            print("other task in downloadImageWithTimeout cancelled")
        }
        print("exiting downloadImageWithTimeout")
    }




    private func downloadImage(of date: Date, updateUI: Bool = true) async throws {
        logger.info("Starting image download for date: \(date)")

        guard let jpg_metadata = (await bingWallpaper.downloadImage(of: date))?.images.first else {
            logger.error("Failed to download image data from Bing")
            throw ImageDownloadError.imageDownloadFailed
        }

        let imageURL = jpg_metadata.getImageURL()
        var image = try await createNSImage(from: imageURL)
        
        // Ensure image is freed at function exit
        defer { image = nil }
                    
        guard let valid_image = image else {
            logger.error("Failed to create NSImage from URL: \(imageURL)")
            throw ImageDownloadError.imageCreationFailed
        }

        let imagePath = folderPath.appendingPathComponent(jpg_metadata.getImageName())

        do {
            let worked = try await saveImage(valid_image, to: imagePath)
            guard worked else {
                logger.error("Failed to save image to: \(imagePath)")
                throw ImageDownloadError.imageSaveFailed
            }
            logger.info("Successfully saved image to: \(imagePath)")
        } catch {
            logger.error("Error saving image: \(error.localizedDescription)")
            throw ImageDownloadError.imageSaveFailed
        }

        do {
            try await jpg_metadata.saveFile(to_dir: metadataPath)
            logger.info("Successfully saved metadata")
        } catch {
            logger.error("Failed to save metadata: \(error.localizedDescription)")
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
