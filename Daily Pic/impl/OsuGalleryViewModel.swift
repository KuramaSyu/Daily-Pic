//
//  imageManager.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI
import UniformTypeIdentifiers
import os



// MARK: - GalleryViewModel
final class OsuGalleryViewModel: ObservableObject, GalleryViewModelProtocol {
    typealias imageType = NamedOsuImage
    //static let shared = GalleryViewModel() // Singleton instance
    @Published var image: NamedOsuImage? = nil
    @Published var revealNextImage: RevealNextImageViewModel?
    @Published var favoriteImages: Set<imageType>
    @Published var galleryModel: OsuGalleryModel
    @Published var imageTracker: ImageTrackerProtocol

    @Published var config: Config
    var imageIterator: StrategyBasedImageIterator<NamedOsuImage>

    // Private initializer to restrict instantiation
    init(
        galleryModel: OsuGalleryModel,
        imageTracker: any ImageTrackerProtocol,
    ) {
        // set iterator with any random image strategy
        var imageIterator = StrategyBasedImageIterator(
            items: [] as [imageType],
            strategy: AnyRandomImageStrategy<imageType>()
        )
        self.imageIterator = imageIterator

        // no next image to reveal
        self.revealNextImage = nil
        
        // set Gallery Model to the osu one
        self.galleryModel = galleryModel

        // set image tracker to osu tracker
        self.imageTracker = imageTracker
        
        // load config
        let config = OsuGalleryViewModel.initialsize_environment(galleryModel: galleryModel)
        self.config = config

        // load favorite images
        self.favoriteImages = Set<imageType>();
        OsuGalleryViewModel.loadFavorite(config: config, favoriteImages: &self.favoriteImages)
        
        let strategy: AnyImageSelectionStrategy<imageType>
        if config.toggles.shuffle_favorites_only {
            strategy = AnyImageSelectionStrategy(
                FavoriteRandomImageStrategy<imageType>(favorites: self.favoriteImages)
            )
        } else {
            strategy = AnyImageSelectionStrategy(
                AnyRandomImageStrategy<imageType>()
            )
        }

        // set strategy to ByDate for re
        OsuGalleryViewModel.loadImages(
            revealNextImage: nil, galleryModel: galleryModel, imageIterator: &self.imageIterator)
        
        // set image to the last image of the iterator
        self.image = imageIterator.last()
        imageIterator = StrategyBasedImageIterator(
            items: galleryModel.images,
            strategy: strategy
        )
        showLastImage()
        loadCurrentImage()
    }

    func getItems() -> [any NamedImageProtocol] {
        return imageIterator.getItems()
    }

    func setImage(_ new: NamedOsuImage?) {
        guard let new = new else { return }
        if !new.exists() {
            print("image does not exist - laod")
            OsuGalleryViewModel.loadImages(
                revealNextImage: self.revealNextImage, galleryModel: self.galleryModel,
                imageIterator: &self.imageIterator)
            return
        }
        if image != nil && !image!.exists() {
            OsuGalleryViewModel.loadImages(
                revealNextImage: self.revealNextImage, galleryModel: self.galleryModel,
                imageIterator: &self.imageIterator)
            imageIterator.setIndexByUrl(new.url)
        }
        if config.toggles.set_wallpaper_on_navigation == true {
            WallpaperHandler().setWallpaper(image: new.url)
        }
        image = new
    }
    // Computed property to get the current image
    var currentImage: NamedOsuImage? {
        if let image = image {
            image.getMetaData()
        }
        return image
    }

    var currentImageUrl: URL? {
        guard image != nil else { return nil }
        return image!.url
    }

    static func initialsize_environment(galleryModel: any GalleryModelProtocol) -> Config {
        ensureFileExists(
            path: galleryModel.galleryPath.appendingPathComponent("config.json"),
            default_value: Config.getDefault()
        )
        return loadConfig(galleryModel: galleryModel)
    }

    func isCurrentFavorite() -> Bool {
        guard image != nil else {
            return false
        }
        let contained = favoriteImages.contains(image!)
        return contained
    }

    // Ensure the folder exists (creates it if necessary)
    static func ensureFolderExists(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folder, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(folder.path)")
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }

    func loadCurrentImage() {
        guard image != nil else { return }
        image!.getMetaData()
        if config.toggles.set_wallpaper_on_navigation {
            WallpaperHandler().setWallpaper(image: image!.url)
        }
    }

    func onDisappear() {
        print("run cleanup task")
        // Clear any cached image data
        URLCache.shared.removeAllCachedResponses()
    }

    /// Load images from the folder using the <galleryModel> and sets them as items in the <imageIterator>
    @Sendable static func loadImages(
        revealNextImage: RevealNextImageViewModel?, galleryModel: OsuGalleryModel,
        imageIterator: inout StrategyBasedImageIterator<NamedOsuImage>
    ) {
        var hiddenDates: Set<Date> = []
        if let nextReveal = revealNextImage {
            if let date = nextReveal.imageDate {
                hiddenDates.insert(date)
            }
        }
        print("hide date: \(hiddenDates)")
        galleryModel.reloadImages(hiddenDates: hiddenDates)

        imageIterator.setItems(galleryModel.images, track_index: true)
    }

    /// Load images from the folder using the <galleryModel> and sets them as items in the <imageIterator>
    @Sendable func selfLoadImages() {
        var hiddenDates: Set<Date> = []
        if let nextReveal = revealNextImage {
            if let date = nextReveal.imageDate {
                hiddenDates.insert(date)
            }
        }
        Swift.print(#function)
        galleryModel.reloadImages(hiddenDates: hiddenDates)

        imageIterator.setItems(galleryModel.images, track_index: true)
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
            print("Favorite action triggered for image \(image.getDescription())")
            favoriteImages.insert(image)
            self.config.favorites.insert(image.url.path())
        }

    }

    func unFavoriteCurrentImage() {
        if let image = image {
            print("Unfavorite action triggered for image at index \(image.getDescription())")
            favoriteImages.remove(image)
            self.config.favorites.remove(image.url.path())
        }

    }

    // opens the picture folder
    func openFolder() {
        NSWorkspace.shared.open(galleryModel.galleryPath)
    }

    /// ensures that path exists else init it with default_value
    static func ensureFileExists(path: URL, default_value: Codable) {
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
    static func loadFavorite<T: NamedImageProtocol>(config: Config, favoriteImages: inout Set<T>) {
        for favorite in config.favorites {
            guard let fileURL = URL(string: favorite) else { continue }
            favoriteImages.insert(
                T.init(
                    url: fileURL,
                    creation_date: Date(),  // Modify as needed
                    image: nil  // Defer loading the image
                )
            )
        }
        print("Loaded \(favoriteImages.count) favorite images")
    }

    static func loadConfig(galleryModel: any GalleryModelProtocol) -> Config {
        print("Loading config")
        let favoritesPath = galleryModel.galleryPath.appendingPathComponent("config.json")
        if let r_config = Config.load(from: favoritesPath) {
            return r_config
        } else {
            print("Failed to load config, use default config")
            return Config.getDefault()
        }
    }

    func writeConfig() {
        config.write(to: galleryModel.galleryPath.appendingPathComponent("config.json"))
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
        if config.toggles.shuffle_favorites_only == true {
            imageIterator.setStrategy(FavoriteRandomImageStrategy(favorites: favoriteImages))
        } else {
            imageIterator.setStrategy(AnyRandomImageStrategy<imageType>())
        }
        setImage(imageIterator.random())
    }

    // search the previous url and set image index to it
    func setIndexByUrl(_ current_image_url: URL) {
        imageIterator.setIndexByUrl(current_image_url)
    }
}
