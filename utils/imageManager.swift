//
//  imageManager.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI
import os

enum ImageDownloadError: Error {
    case imageDownloadFailed
    case imageCreationFailed
    case imageSaveFailed
    case metadataSaveFailed
    
    var localizedDescription: String {
        switch self {
        case .imageDownloadFailed: return "Failed to download image from Bing"
        case .imageCreationFailed: return "Failed to create image from URL"
        case .imageSaveFailed: return "Failed to save image to disk"
        case .metadataSaveFailed: return "Failed to save image metadata"
        }
    }
}



// MARK: - Image Manager
class ImageManager: ObservableObject {
    static let shared = ImageManager() // Singleton instance
    
    var images: [NamedImage] = []
    @Published private var _currentIndex: Int = 0
    @Published var revealNextImage: RevealNextImage? = nil
    
    var currentIndex: Int {
        get {
            _currentIndex
        }
        set {
            DispatchQueue.main.async {
                self._currentIndex = newValue
                print("set Index to \(newValue)")
                self.loadCurrentImage()
            }
        }
    }

    @Published var favoriteImages: Set<NamedImage> = []
    var bingWallpaper: BingWallpaper
    

    private let folderPath: URL
    private let metadataPath: URL
    @Published var config: Config? = nil

    // Private initializer to restrict instantiation
    private init() {
        bingWallpaper = BingWallpaper.shared
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        folderPath = documentsPath.appendingPathComponent("DailyPic")
        metadataPath = folderPath.appendingPathComponent("metadata")
        initialsize_environment()
        loadImages()
        showLastImage()
        loadCurrentImage()
    }
    
    // Singleton access ensures only one instance
    static func getInstance() -> ImageManager {
        return shared
    }
    
    // Computed property to get the current image
    var currentImage: NamedImage? {
        guard !images.isEmpty, currentIndex >= 0, currentIndex < images.count else { return nil }
        let image = images[currentIndex]
        return image
    }
                    
    var currentImageUrl: URL? {
        guard !images.isEmpty, currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex].url
    }

    
    func initialsize_environment() {
        ensureFolderExists(folder: folderPath)
        ensureFileExists(
            path: folderPath.appendingPathComponent("config.json"),
            default_value: Config.getDefault()
        )
        ensureFolderExists(folder: metadataPath)
        loadConfig()
    }
        
    func isCurrentFavorite() -> Bool {
        guard images.indices.contains(currentIndex) else {
            return false
        }
        let currentImage = images[currentIndex]
        let contained = favoriteImages.contains(currentImage)
        return contained
    }
    
    // Ensure the folder exists (creates it if necessary)
    func ensureFolderExists(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(folder.path)")
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }
    
    func loadCurrentImage() {
        if images.count == 0 {
            return
        }
        images[currentIndex].getMetaData(from: metadataPath)
        if config!.toggles.set_wallpaper_on_navigation {
            WallpaperHandler().setWallpaper(image: images[currentIndex].url)
        }
        
        // unload other images
        for (i, image) in images.enumerated() where i != currentIndex {
            image.unloadImage()
        }
    }
    
    func onDisappear() {
        print("run cleanup task")
        for image in images {
            image.unloadImage()
        }
        // Optional: Clear any cached image data
        URLCache.shared.removeAllCachedResponses()
    }
    
    // Load images from the folder
    @Sendable func loadImages() {
        do {
            // Retrieve file URLs with their creation date
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderPath, includingPropertiesForKeys: [.creationDateKey])
            
            // Filter only image files (png, jpg)
            let imageFiles = fileURLs.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "png" || ext == "jpg"
            }
            

            
            // Map to an array of NamedImage objects
            var unsorted_images = imageFiles.compactMap { fileURL in
                if let _ = NSImage(contentsOf: fileURL),
                   let creationDate = (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate {
                    return NamedImage(
                        url: fileURL,
                        creation_date: creationDate,
                        image: nil  // only load when needed
                    )
                }
                return nil
            }
            
            // hide last image if needs to be revealed
            
            if let nextImage = self.revealNextImage {
                let calendar = Calendar.autoupdatingCurrent
                unsorted_images = unsorted_images.filter {
                    nextImage.imageUrl != $0.url && nextImage.imageDate != calendar.startOfDay(for: $0.getDate())
                }
            }
            // Sort by creation date
            images = unsorted_images.sorted {
                $0.getDate() < $1.getDate()
            }
            
            // Reset current index if it is out of bounds
            if !images.indices.contains(currentIndex) {
                showLastImage()
            }
            
            print("\(images.count) images loaded.")
        } catch {
            print("Failed to load images: \(error)")
        }
    }
    
    func getMissingDates() -> [Date] {
        // Determine the last 7 days
        let calendar = Calendar.autoupdatingCurrent
        let today = Date()
        var daysToAdd: [Date] = []
        var missingDates: [Date] = []
        print("\(calendar.startOfDay(for: today)) -- \(today.description(with: .autoupdatingCurrent))")
        for i in 0..<15 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                daysToAdd.append(calendar.startOfDay(for: date))
                //daysToAdd.append(date)
            }
        }
        
        // Check for missing days and add NamedImage with nil image if necessary
        let existingDates = Set(images.map { $0.getDate() })
        for date in daysToAdd {
            if !existingDates.contains(date) {
                missingDates.append(date)
            }
        }
        print("Missing dates: \(missingDates)")
        return missingDates
    }

    func showLastImage() {
        currentIndex = images.count - 1
    }
    // Show the previous image
    func showPreviousImage() {
        if !images.isEmpty {
            currentIndex = max((currentIndex - 1), 0)
        }
    }

    // Show the next image
    func showNextImage() {
        if !images.isEmpty {
            currentIndex = min((currentIndex + 1), images.count - 1)
        }
    }
    
    func showLastFavoriteImage() {
        currentIndex = favoriteImages.count - 1
    }
    
    func showFirstImage() {
        currentIndex = 0
    }
    
    func isLastImage() -> Bool {
        return currentIndex >= images.count - 1
    }
    
    func isFirstImage() -> Bool {
        return currentIndex <= 0
    }

    // Placeholder for favoriting functionality
    func favoriteCurrentImage() {
        print("Favorite action triggered for image at index \(currentIndex)")
        favoriteImages.insert(images[currentIndex])
        self.config?.favorites.insert(images[currentIndex].url.path())
        
    }
    
    func unFavoriteCurrentImage() {
        print("Unfavorite action triggered for image at index \(currentIndex)")
        favoriteImages.remove(images[currentIndex])
        self.config?.favorites.remove(images[currentIndex].url.path())
    }
    
    // opens the picture folder
    func openFolder() {
        NSWorkspace.shared.open(folderPath)
    }
    
    /// ensures that path exists else init it with default_value
    func ensureFileExists(path: URL, default_value: Codable) {
        guard !FileManager.default.fileExists(atPath: path.path) else { return }
    
        
        // Encode the Config instance to Data
        let encoder = JSONEncoder()
        if let configData = try? encoder.encode(default_value) {
            // Create the file with the encoded data
            FileManager.default.createFile(
                atPath: path.path,
                contents: configData,
                attributes: nil
            )
        } else {
            // Handle error if encoding fails
            print("Failed to encode path: \(path)")
        }
    }

    /// Loads favorite images from config.favorites into self.favoriteImages
    func loadFavorite() {
        if config == nil {return}
        let config = self.config!
        for favorite in config.favorites {
            if let image = NSImage(contentsOfFile: favorite) {
                print("Found favorite image: \(favorite)")
                self.favoriteImages.insert(
                    NamedImage(
                        url: URL(string: favorite)!,
                        creation_date: Date(),
                        image: image
                    )
                )
            }
        }
        print("Loaded \(favoriteImages.count) favorite images)")
    }
        
    func loadConfig() {
        print("Loading config")
        let favoritesPath = folderPath.appendingPathComponent("config.json")
        if let r_config = Config.load(from: favoritesPath) {
            config = r_config
        } else {
            print("Failed to load config, use default config")
            config = Config.getDefault()
        }
        self.loadFavorite()
    }

    func writeConfig() {
        config?.write(to: folderPath.appendingPathComponent("config.json"))
    }
    
    func makeFavorite(bool: Bool) {
        if bool {
            favoriteCurrentImage()
        } else {
            unFavoriteCurrentImage()
        }
        writeConfig()
    }
    
    // for bing download
    func runDailyTaskIfNeeded() {
        print("Trialling daily task...")
        if shouldRunDailyTask() {
            print("Running daily task after wake or app load...")
            // Example: Perform your daily task here
            loadImages() // Example task
            markDailyTaskAsRun()
        }
    }

    func shouldRunDailyTask() -> Bool {
        let today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let lastRunDate = UserDefaults.standard.object(forKey: "LastDailyTaskRunDate") as? Date ?? .distantPast
        return lastRunDate < today
    }

    func markDailyTaskAsRun() {
        let today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: "LastDailyTaskRunDate")
    }
    
    func shuffleIndex() {
        if config?.toggles.shuffle_favorites_only ?? false && !favoriteImages.isEmpty{
            let image = favoriteImages.shuffled()[0]
            
            // Search for the index of this image in the images array
            if let index = images.firstIndex(where: { $0 == image }) {
                currentIndex = index
            } else {
                // If the image isn't found, handle this case (perhaps set currentIndex to a default value)
                currentIndex = 0
            }
        } else {
            currentIndex = Int.random(in: 0...images.count - 1)
        }
    }
    
    // downloads images of last 7 days where image is missing, but does not update UI
    // returns the updated dates
    // the images need to be reloaded afterwards
    func downloadMissingImages(from dates: [Date]? = nil) async -> [Date] {
        print("start downloading missing images...")
        let today_start = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let missingDates: [Date] = dates ?? getMissingDates()
        for date in missingDates {
            do {
                try await downloadImage(of: date, update_ui: false)
                await MainActor.run {
                    if date == today_start && self.revealNextImage == nil {
                        print("trigger reveal from downloadMissingImages")
                        let revealImage = RevealNextImage.new(date: today_start)
                        self.revealNextImage = revealImage
                    }
                }
                if let image = self.revealNextImage {
                    if image.triggerStarted == false {
                        await image.startTrigger()
                    }
                }
            } catch is ImageDownloadError {}
            catch {}
        }
        if let image = self.revealNextImage {
            await image.startTrigger()
        }
        return missingDates
    }
    
    
    /// downloads image of <date>
    func downloadImage(of date: Date, update_ui: Bool = true) async throws {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ImageDownloader", category: "ImageDownload")
        logger.info("Starting image download for date: \(date)")
        
        // 1. Download image data from Bing
        guard let first_image = (await bingWallpaper.downloadImage(of: date))?.images.first else {
            logger.error("Failed to download image data from Bing")
            throw ImageDownloadError.imageDownloadFailed
        }
        
        // 2. Create image from URL
        let image_url = first_image.getImageURL()

        guard let image = try await createNSImage(from: image_url) else {
            logger.error("Failed to create NSImage from URL: \(image_url)")
            throw ImageDownloadError.imageCreationFailed
        }
        
        // 3. Setup paths
        let image_path = folderPath.appendingPathComponent(first_image.getImageName())
        
        // 4. Save image
        do {
            let worked = try await saveImage(image, to: image_path)
            guard worked else {
                logger.error("Failed to save image to: \(image_path)")
                throw ImageDownloadError.imageSaveFailed
            }
            logger.info("Successfully saved image to: \(image_path)")
        } catch {
            logger.error("Error saving image: \(error.localizedDescription)")
            throw ImageDownloadError.imageSaveFailed
        }
        
        // 5. Save metadata
        do {
            try await first_image.saveFile(to_dir: metadataPath)
            logger.info("Successfully saved metadata")
        } catch {
            logger.error("Failed to save metadata: \(error.localizedDescription)")
            throw ImageDownloadError.metadataSaveFailed
        }
        
        // 6. Update UI if needed
        await MainActor.run {
            logger.info("Image and metadata successfully saved")
            if update_ui {
                loadImages()
                showLastImage()
            }
        }
    }
    
    // search the previous url and set image index to it
    func setIndexByUrl(_ current_image_url: URL) {
        var index_of_previous_image: Int? = nil
        for (index, image) in images.enumerated() {
            if image.url == current_image_url {
                index_of_previous_image = index
                print("New index of previous image: \(index)")
                break
            }
        }
        if let index = index_of_previous_image {
            currentIndex = index
        }
    }
}



// Function to create an NSImage from a URL asynchronously
func createNSImage(from url: URL) async throws -> NSImage? {
    // Use URLSession to fetch the data asynchronously
    let (data, _) = try await URLSession.shared.data(from: url)
    
    // Create and return an NSImage from the data
    return NSImage(data: data)
}


// Function to save an NSImage to a file at a given path asynchronously
func saveImage(_ image: NSImage, to path: URL, as format: NSBitmapImageRep.FileType = .jpeg) async throws -> Bool {
    // Perform image processing on a background thread
    return try await Task.detached(priority: .userInitiated) {
        guard let tiffData = image.tiffRepresentation else {
            print("Failed to convert NSImage to TIFF representation.")
            return false
        }
        
        guard let imageRep = NSBitmapImageRep(data: tiffData) else {
            print("Failed to create bitmap representation from TIFF data.")
            return false
        }
        
        // Convert image to the desired format (e.g., PNG or JPEG)
        guard let imageData = imageRep.representation(using: format, properties: [:]) else {
            print("Failed to convert image to specified format.")
            return false
        }
        
        // Write the data to the specified path
        do {
            try imageData.write(to: path)
            print("Image successfully saved to \(path.path)")
            return true
        } catch {
            throw error
        }
    }.value
    


}
