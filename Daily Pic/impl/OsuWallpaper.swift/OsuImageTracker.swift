import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers


class OsuImageTrackerView: ImageTrackerViewProtocol {
    func reloadImages() async {
        print("update images")
        await MainActor.run {
            OsuGalleryViewModel.shared.selfLoadImages()
        }
    }
    
    func setImageReveal(date: Date) async {
        await MainActor.run {
            if OsuGalleryViewModel.shared.revealNextImage != nil {
                return
            }
            print("Reveal from OsuImageTracker")
            let revealNextImage = RevealNextImageViewModel.new(date: date, vm: OsuGalleryViewModel.shared)
            OsuGalleryViewModel.shared.revealNextImage = revealNextImage
        }
    }
    
    func setImageRevealMessage(message: String) async {
        await MainActor.run {
            OsuGalleryViewModel.shared.revealNextImage?.viewInfoMessage = message
        }
    }
}

/// OsuImageTracker tracks by checking the filesystem for the last resposne (saved by date) and
/// comparing it the the fetched one once per day
class OsuImageTracker: ImageTrackerProtocol {
    let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OsuImageDownloader", category: "Image Tracker")
    private let imagePath: URL
    private let metadataPath: URL
    private let osuWallpaper: WallpaperApiProtocol
    private let gallery: any GalleryModelProtocol
    private var isDownloading = false // Tracks whether a download is in progress
    private let downloadLock = DownloadLock()
    private let view = OsuImageTrackerView();
    private let lastCheck: Date?

    required init(gallery: any GalleryModelProtocol, wallpaperApi: any WallpaperApiProtocol) {
        self.gallery = gallery
        self.imagePath = gallery.imagePath
        self.metadataPath = gallery.metadataPath
        self.osuWallpaper = wallpaperApi
        self.lastCheck = nil
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
    
    
    private func fetchedToday() -> Bool {
        return DateParser.getTodayMidnight() == lastCheck
    }
    
    func downloadMissingImages(from dates: [Date]? = nil, reloadImages: Bool = false) async -> [Date] {
        // Use the DownloadLock to ensure only one execution at a time
        guard await downloadLock.tryLock() else {
            log.warning("Download operation (osu) already in progress.")
            return []
        }
        defer { Task { await downloadLock.unlock() } }
        if isDownloading {
            log.warning("Download operation (osu) already in progress.")
            return []
        }
        
        if let reveal = OsuGalleryViewModel.shared.revealNextImage {
            await reveal.removeIfOverdue()
        }
        
        if OsuGalleryViewModel.shared.revealNextImage != nil {
            log.debug("Seems like image reveal is sheduled")
            return []
        }
        
        isDownloading = true
        defer { isDownloading = false } // Reset state when done
        
        // update images of manager
        if reloadImages {
            log.info("update images")
            await MainActor.run {
                OsuGalleryViewModel.shared.selfLoadImages()
            }
        }

        let fetchedToday: Bool = fetchedToday();
        if fetchedToday {
            log.debug("Seems like osu! api was checked today")
            return []
        }
        let downloadedDates: [Date] = []
        

        
        // async fetch all images
        let date = DateParser.getTodayMidnight()
        do {
            // fetch WallpaperResponse
            let wallpapers = await osuWallpaper.downloadImage(of: date)
            guard let images = wallpapers?.images else {
                self.log.debug( "No osu! image(s) found for date \(date)")
                return []
            }
            
            // check if WallpaperResponse (loaded JSON) is new
            let osuResponseTracker = OsuApiResposneTracker(
                galleryModel: self.gallery,
                response: wallpapers as! OsuApiResposneTracker.osuResponseCodable
            )
            if !osuResponseTracker.isNew() {
                self.log.debug("osu! API response seems to be downloaded already")
                // already downloaded
                return []
            }
            
            await self.view.setImageReveal(date: DateParser.getTodayMidnight())
            await self.view.setImageRevealMessage(message: "Downloading \(images.count) osu! Images (0/\(images.count))")
            
            for (i, wallpaper) in images.enumerated() {
                self.log.debug("Downloadung osu! image \(i)")
                await self.view.setImageRevealMessage(message: "Downloading \(images.count) osu! Images (\(i+1)/\(images.count))")
                try await self.downloadImageWithTimeout(jpg_metadata: wallpaper)
            }
            self.log.debug("finished a osu download")
            try osuResponseTracker.store()

        } catch {
            self.log.error("Error downloading osu! image(s) for date \(date): \(error.localizedDescription)")
            await OsuGalleryViewModel.shared.revealNextImage?.deleteTrigger()

        }

        Task { await OsuGalleryViewModel.shared.revealNextImage?.startTrigger() }
        await self.view.setImageRevealMessage(message: "next osu image ready")

        return downloadedDates
    }

    private func downloadImageWithTimeout(jpg_metadata: WallpaperProtocol) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the download task
            let MAX_ATTEMPTS = 5
            group.addTask {
                for attempt in 1...MAX_ATTEMPTS {
                    do {
                        try await self.downloadImage(jpg_metadata: jpg_metadata)
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
    
    
    private func downloadImage(jpg_metadata: WallpaperProtocol) async throws {
        let imageURL = jpg_metadata.getImageURL()
        log.info("Starting image download for date: \(DateParser.getTodayMidnight())")
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


/// Keeps track of the seasonal-wallpaper API Response
/// from osu!, by storing a SHA256 Hash + Date of the response
/// in a JSON file.
class OsuApiResposneTracker {
    typealias osuResponseCodable = OsuWallpaperAdapter;
    private let storageURL: URL
    private let response: osuResponseCodable
    private var loadedResposne: Set<FetchedRecord>?
    
    init(galleryModel: any GalleryModelProtocol, response: osuResponseCodable) {
        let galleryPath = galleryModel.galleryPath
        self.storageURL = galleryPath.appendingPathComponent("api_responses.json")
        self.response = response
        self.loadedResposne = nil
    }
    
    private func hash() -> String {
        return try! sha256Hex(self.response.response)
    }
    
    private func loadJson() -> Set<FetchedRecord> {
        do {
            self.loadedResposne = try loadFromJson(Set<FetchedRecord>.self, from: self.storageURL)
        } catch {
            return []
        }
        return self.loadedResposne!
    }
    
    private func writeJson<T: Codable>(_ value: T) {
        return try! writeToJson(data: value, to: self.storageURL)
    }
    
    /// checks, if the given response is new.
    /// if yes, it's inserted into responses
    func isNew() -> Bool {
        var api_responses = self.loadJson()
        let hash = self.hash()
        
        // check if hash is already stored
        for response in api_responses {
            if response.sha256 == hash {
                return false
            }
        }
        return true
    }
    
    /// stores the hash of the injected osuResponse into the JSON
    func store() throws {
        var api_responses = self.loadJson()
        let hash = self.hash();
        // hash is new -> store it
        api_responses.insert(FetchedRecord(date: DateParser.getTodayMidnight(), sha256: hash))
        self.writeJson(api_responses)
    }
}
