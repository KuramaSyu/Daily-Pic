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
class GalleryViewModel: ObservableObject {
    static let shared = GalleryViewModel() // Singleton instance
    
    @Published var image: NamedImage? = nil
    @Published var revealNextImage: RevealNextImageViewModel? = nil
    @Published var favoriteImages: Set<NamedImage> = []
    @Published var gallery_model: BingGalleryModel = BingGalleryModel.shared
   
    var bingWallpaper: BingWallpaperAPI
    
    @Published var config: Config? = nil
    var imageIterator: StrategyBasedImageIterator = StrategyBasedImageIterator(items: [], strategy: AnyRandomImageStrategy())

    // Private initializer to restrict instantiation
    private init() {
        bingWallpaper = BingWallpaperAPI.shared
        initialsize_environment()
        loadImages()
        let strategy: ImageSelectionStrategy
        if config!.toggles.shuffle_favorites_only {
            strategy = FavoriteRandomImageStrategy(favorites: self.favoriteImages)
        } else {
            strategy = AnyRandomImageStrategy()
        }
        imageIterator = StrategyBasedImageIterator(items: gallery_model.images, strategy: strategy)
        showLastImage()
        loadCurrentImage()
        
    }
    
    // Singleton access ensures only one instance
    static func getInstance() -> GalleryViewModel {
        return shared
    }
    
    func getItems() -> [NamedImage] {
        return imageIterator.getItems()
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
            image.getMetaData()
        }
        return image
    }
                    
    var currentImageUrl: URL? {
        guard image != nil else { return nil }
        return image!.url
    }

    
    func initialsize_environment() {
        ensureFileExists(
            path: gallery_model.folderPath.appendingPathComponent("config.json"),
            default_value: Config.getDefault()
        )
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
        image!.getMetaData()
        if config!.toggles.set_wallpaper_on_navigation {
            WallpaperHandler().setWallpaper(image: image!.url)
        }
    }
    
    func onDisappear() {
        print("run cleanup task")
        // Clear any cached image data
        URLCache.shared.removeAllCachedResponses()
    }
    
    /// Load images from the folder
    @Sendable func loadImages() {
        var hiddenDates: Set<Date> = [];
        if let nextReveal = revealNextImage {
            if let date = nextReveal.imageDate {
                hiddenDates.insert(date)
            }
        }
        print("hide date: \(hiddenDates)")
        gallery_model.reloadImages(hiddenDates: hiddenDates)

        imageIterator.setItems(gallery_model.images, track_index: true)
        
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
        NSWorkspace.shared.open(gallery_model.folderPath)
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
        let favoritesPath = gallery_model.folderPath.appendingPathComponent("config.json")
        if let r_config = Config.load(from: favoritesPath) {
            config = r_config
        } else {
            print("Failed to load config, use default config")
            config = Config.getDefault()
        }
        self.loadFavorite()
    }

    func writeConfig() {
        config?.write(to: gallery_model.folderPath.appendingPathComponent("config.json"))
    }
    
    func makeFavorite(bool: Bool) {
        if bool {
            favoriteCurrentImage()
        } else {
            unFavoriteCurrentImage()
        }
        writeConfig()
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







