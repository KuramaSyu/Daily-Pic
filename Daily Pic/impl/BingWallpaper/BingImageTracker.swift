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
    private let vm = any GalleryViewModelProtocol
    init(vm: any GalleryViewModelProtocol) {
        self.vm = vm
    }
    
    func reloadImages() async {
        print("update images")
        await MainActor.run {
            self.vm.selfLoadImages()
        }
    }
    
    func setImageReveal(date: Date) async {
        await MainActor.run {
            if self.vm.revealNextImage != nil {
                return
            }
            print("Reveal from BingImageTracker")
            let revealNextImage = RevealNextImageViewModel.new(date: date, vm: BingGalleryViewModel.shared)
            self.vm.revealNextImage = revealNextImage
        }
    }
    
    func setImageRevealMessage(message: String) async {
        await MainActor.run {
            self.vm.revealNextImage?.viewInfoMessage = message
        }
    }
}

/// BingImageTracker tracks by checking the filesystem which images and dates exist. Then it downloads missing
/// images via the BingWallpaperAPI
class BingImageTracker: ImageTrackerProtocol {
    let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ImageDownloader", category: "Image Tracker")
    private let imagePath: URL
    private let metadataPath: URL
    private let bingWallpaper: WallpaperApiProtocol
    private let gallery: any GalleryModelProtocol
    private var isDownloading = false // Tracks whether a download is in progress
    private let downloadLock = DownloadLock()
    private let view: any ImageTrackerViewProtocol;
    private let vm: any GalleryViewModelProtocol
    private let viewMaker: ZeroArgFactory<BingImageTrackerView>

    required init(
        gallery: any GalleryModelProtocol,
        wallpaperApi: any WallpaperApiProtocol,
        viewModel: any GalleryViewModelProtocol,
        trackerViewFactory: @escaping ZeroArgFactory<BingImageTrackerView>
    ) {
        self.gallery = gallery
        self.imagePath = gallery.imagePath
        self.metadataPath = gallery.metadataPath
        self.bingWallpaper = wallpaperApi
        self.vm = viewModel
        self.viewMaker = trackerViewFactory
        self.view = viewMaker()
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

        let images = gallery.images
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
    
    
    func downloadMissingImages(from dates: [Date]? = nil, reloadImages: Bool = false) async throws -> [Date] {
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
        
        if let reveal = self.vm.revealNextImage {
            await reveal.removeIfOverdue()
        }
        
        if self.vm.revealNextImage != nil {
            log.debug("Seems like image reveal is sheduled")
            return []
        }
        
        // update images of manager
        if reloadImages {
            log.info("update images")
            await MainActor.run {
                self.vm.selfLoadImages()
            }
        }

        let missingDates: [Date] = dates ?? getMissingDates()
        if missingDates.isEmpty {
            log.debug("Seems like there are no images to download")
            return []
        }
        var downloadedDates: [Date] = []
        
        await self.view.setImageReveal(date: DateParser.getTodayMidnight())
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
                        await self.vm.revealNextImage?.deleteTrigger()
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
        Task { await self.vm.revealNextImage?.startTrigger() }
        await self.view.setImageRevealMessage(message: "next image ready")

        return downloadedDates
    }

    private func downloadImageWithTimeout(of date: Date) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the download task
            let MAX_ATTEMPTS = 5
            group.addTask {
                for attempt in 1...MAX_ATTEMPTS {
                    do {
                        try await self.downloadImage(of: date)
                        break // Success, exit the loop
                    } catch let error as URLError where error.code == .notConnectedToInternet {
                        if attempt == MAX_ATTEMPTS {
                            throw error // Rethrow after final attempt
                        }
                        await self.view.setImageRevealMessage(message: "No internet connection. Try \(attempt)/\(MAX_ATTEMPTS) starts in 1 minute")
                        // Optional: Wait before retrying
                        try await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60s
                    } catch {
                        // Other errors, don't retry
                        throw error
                    }
                }
            }
            
            // Add the timeout task
            group.addTask {
                let totalDuration: UInt64 = 10 * 60 * 1_000_000_000 // 10 minutes
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




    private func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 300   // large images
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: cfg)
    }
    
    func downloadToTempFile(_ url: URL, session: URLSession) async throws -> URL {
        let (tempURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return tempURL
    }
    
    
    private func downloadImage(of date: Date, updateUI: Bool = true) async throws {
        log.info("Starting image download for date: \(date)")

        guard let jpg_metadata = (try await bingWallpaper.fetchResponse(of: date))?.images.first else {
            log.error("Failed to download image data from Bing")
            throw ImageDownloadError.imageDownloadFailed
        }

        let imageURL = jpg_metadata.getImageURL()
        let session = makeSession()

        // Stream to disk, no big Data buffers.
        let tempURL = try await downloadToTempFile(imageURL, session: session)
        
        var image = try await createNSImage(from: tempURL)
        
        // Ensure image is freed at function exit
        defer { image = nil }
                    
        guard let valid_image = image else {
            log.error("Failed to create NSImage from URL: \(imageURL)")
            throw ImageDownloadError.imageCreationFailed
        }

        let imagePath = imagePath.appendingPathComponent(jpg_metadata.getImageName())

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
            try await jpg_metadata.saveFile()
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
