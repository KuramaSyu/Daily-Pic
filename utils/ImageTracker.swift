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


class BingImageTracker {
    static let shared = BingImageTracker(
        folderPath: ImageManager.getInstance().folderPath,
        metadataPath: ImageManager.getInstance().metadataPath,
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

        let images = ImageManager.getInstance().images
        let existingDates = Set(images.map { $0.getDate() })
        for date in daysToAdd {
            if !existingDates.contains(date) {
                missingDates.append(date)
            }
        }
        return missingDates
    }

    private func set_image_reveal() async {
        await MainActor.run {
            if ImageManager.shared.revealNextImage != nil {
                return
            }
            print("Reveal from BingImageTracker")
            let revealNextImage = RevealNextImage.new(date: get_today())
            ImageManager.shared.revealNextImage = revealNextImage
        }
    }
    
    private func set_image_reveal_message(message: String?) async {
        await MainActor.run {
            ImageManager.shared.revealNextImage?.viewInfoMessage = message
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
    
    
    func downloadMissingImages(from dates: [Date]? = nil, updateUI: Bool = true, reload_images: Bool = false) async -> [Date] {
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
        
        if let reveal = ImageManager.shared.revealNextImage {
            await reveal.removeIfOverdue()
        }
        
        if ImageManager.shared.revealNextImage != nil {
            print("Seems like image reveal is sheduled")
            return []
        }
        
        isDownloading = true
        defer { isDownloading = false } // Reset state when done
        
        // update images of manager
        if reload_images {
            print("update images")
            await MainActor.run {
                ImageManager.shared.loadImages()
            }
        }

        let missingDates: [Date] = dates ?? getMissingDates()
        if missingDates.isEmpty {
            print("Seems like there are no images to download")
            return []
        }
        var downloadedDates: [Date] = []
        
        await self.set_image_reveal()
        await self.set_image_reveal_message(message: "Downloading Images")
        await withTaskGroup(of: (Date, Bool).self) { group in
            for date in missingDates {
                group.addTask {
                    do {
                        try await self.downloadImageWithTimeout(of: date)
                        print("finished a download")
                        return (date, true)
                    } catch {
                        self.logger.error("Error downloading image for date \(date): \(error.localizedDescription)")
                        await ImageManager.shared.revealNextImage?.deleteTrigger()
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
        Task { await ImageManager.shared.revealNextImage?.startTrigger() }
        await self.set_image_reveal_message(message: "next image ready")
        if self.needs_ui_update(dates: downloadedDates) {
            logger.debug("Updating UI...")
            await MainActor.run {
                ImageManager.getInstance().loadImages()
                ImageManager.getInstance().showLastImage()
            }
        }

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

        guard let firstImage = (await bingWallpaper.downloadImage(of: date))?.images.first else {
            logger.error("Failed to download image data from Bing")
            throw ImageDownloadError.imageDownloadFailed
        }

        let imageURL = firstImage.getImageURL()
        guard let image = try await createNSImage(from: imageURL) else {
            logger.error("Failed to create NSImage from URL: \(imageURL)")
            throw ImageDownloadError.imageCreationFailed
        }

        let imagePath = folderPath.appendingPathComponent(firstImage.getImageName())

        do {
            let worked = try await saveImage(image, to: imagePath)
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
            try await firstImage.saveFile(to_dir: metadataPath)
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
