//
//  imageManager.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI
import os
import UniformTypeIdentifiers

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
    private var imageIterator = StrategyBasedImageIterator(items: [], strategy: AnyRandomImageStrategy())
    @Published var image: NamedImage? = nil
    @Published var revealNextImage: RevealNextImage? = nil
    @Published var favoriteImages: Set<NamedImage> = []
    var bingWallpaper: BingWallpaperAPI
    

    let folderPath: URL
    let metadataPath: URL
    @Published var config: Config? = nil

    // Private initializer to restrict instantiation
    private init() {
        bingWallpaper = BingWallpaperAPI.shared
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
    
    func setImage(_ new: NamedImage?) {
        guard let new = new else {return}
        if !new.exists() {
            loadImages()
            return
        }
        if  image != nil && !image!.exists() {
            loadImages()
            imageIterator.setIndexByUrl(new.url)
        }
        if config?.toggles.set_wallpaper_on_navigation == true {
            WallpaperHandler().setWallpaper(image: new.url)
        }
        image = new
    }
    // Computed property to get the current image
    var currentImage: NamedImage? {
        if let image = image {
            image.getMetaData(from: metadataPath)
        }
        return image
    }
                    
    var currentImageUrl: URL? {
        guard image != nil else { return nil }
        return image!.url
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
        guard image != nil else {
            return false
        }
        let contained = favoriteImages.contains(image!)
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
        guard image != nil else {return}
//        if currentIndex >= images.count {
//            self.loadImages()
//            print("Reset current index to \(images.count - 1) - because out of bounds")
//            return self.currentIndex = images.count - 1
//        }
        image!.getMetaData(from: metadataPath)
        if config!.toggles.set_wallpaper_on_navigation {
            WallpaperHandler().setWallpaper(image: image!.url)
        }
    }
    
    func onDisappear() {
        print("run cleanup task")
        for image in images {
            image.unloadImage()
        }
        // Clear any cached image data
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
            var unsorted_images: [NamedImage] = imageFiles.compactMap { fileURL in
                // Check if the file is a valid image without allocating memory for NSImage
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]),
                      let typeIdentifier = resourceValues.typeIdentifier,
                      UTType(typeIdentifier)?.conforms(to: .image) == true,
                      let creationDate = (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate else {
                    return nil
                }

                return NamedImage(
                    url: fileURL,
                    creation_date: creationDate,
                    image: nil  // only load when needed
                )
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
            imageIterator.setItems(images)
            
            print("\(images.count) images loaded.")
        } catch {
            print("Failed to load images: \(error)")
        }
    }
    
    func isFirstImage() -> Bool {
        return imageIterator.isFirst()
    }
    
    func isLastImage() -> Bool {
        return imageIterator.isLast()
    }

    func showLastImage() {
        setImage(imageIterator.last())
    }
    // Show the previous image
    func showPreviousImage() {
        setImage(imageIterator.previous())
    }

    // Show the next image
    func showNextImage() {
        setImage(imageIterator.next())
    }
    
    func showFirstImage() {
        setImage(imageIterator.first())
    }
    

    // Placeholder for favoriting functionality
    func favoriteCurrentImage() {
        if let image = image {
            print("Favorite action triggered for image \(image.description)")
            favoriteImages.insert(image)
            self.config?.favorites.insert(image.url.path())
        }

        
    }
    
    func unFavoriteCurrentImage() {
        if let image = image {
            print("Unfavorite action triggered for image at index \(image.description)")
            favoriteImages.remove(image)
            self.config?.favorites.remove(image.url.path())
        }

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
        guard let config = self.config else { return }
        
        for favorite in config.favorites {
            guard let fileURL = URL(string: favorite) else { continue }
            self.favoriteImages.insert(
                NamedImage(
                    url: fileURL,
                    creation_date: Date(), // Modify as needed
                    image: nil // Defer loading the image
                )
            )
        }
        print("Loaded \(favoriteImages.count) favorite images")
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
        if config?.toggles.shuffle_favorites_only == true {
            imageIterator.setStrategy(FavoriteRandomImageStrategy(favorites: favoriteImages))
        } else {
            imageIterator.setStrategy(AnyRandomImageStrategy())
        }
        setImage(imageIterator.random())
    }
    

    
    // search the previous url and set image index to it
    func setIndexByUrl(_ current_image_url: URL) {
        imageIterator.setIndexByUrl(current_image_url)
    }
}







