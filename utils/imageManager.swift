//
//  imageManager.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI


// MARK: - Image Manager
class ImageManager: ObservableObject {
    @Published var images: [NamedImage] = []
    @Published var currentIndex: Int = 0
    @Published var favoriteImages: Set<NamedImage> = []
    

    private let folderPath: URL
    @Published var config: Config? = nil

    // Computed property to get the current image
    var currentImage: NSImage? {
        guard !images.isEmpty, currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex].image
    }
                    
    var currentImageUrl: URL? {
        guard !images.isEmpty, currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex].url
    }

    init() {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        folderPath = documentsPath.appendingPathComponent("DailyPic")
        ensureConfigExists()
        loadConfig()


    }
    func isCurrentFavorite() -> Bool {
        guard images.indices.contains(currentIndex) else {
            print("currentIndex is out of bounds.")
            return false
        }
        let currentImage = images[currentIndex]
        let contained = favoriteImages.contains(currentImage)
        return contained
    }
    // Ensure the folder exists (creates it if necessary)
    func ensureFolderExists() {
        if !FileManager.default.fileExists(atPath: folderPath.path) {
            do {
                try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(folderPath.path)")
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }

    // Load images from the folder
    func loadImages() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderPath, includingPropertiesForKeys: nil)
            let imageFiles = fileURLs.filter { $0.pathExtension.lowercased() == "png" || $0.pathExtension.lowercased() == "jpg" }

            images = imageFiles.compactMap {
                if let image = NSImage(contentsOf: $0) {
                    return NamedImage(
                        image: image,
                        url: $0
                    )
                }
                return nil
            }
            if !images.indices.contains(currentIndex) {
                currentIndex = 0 // Reset to the first image
            }
            
            print("\(images.count) images loaded.")
        } catch {
            print("Failed to load images: \(error)")
        }
    }

    // Show the previous image
    func showPreviousImage() {
        if !images.isEmpty {
            currentIndex = (currentIndex - 1 + images.count) % images.count
        }
    }

    // Show the next image
    func showNextImage() {
        if !images.isEmpty {
            currentIndex = (currentIndex + 1) % images.count
        }
    }

    // Placeholder for favoriting functionality
    func favoriteCurrentImage() {
        print("Favorite action triggered for image at index \(currentIndex)")
        favoriteImages.insert(images[currentIndex])
        self.config?.favorites.insert(images[currentIndex].url.path())
        
    }
    
    // opens the picture folder
    func openFolder() {
        NSWorkspace.shared.open(folderPath)
    }
    func ensureConfigExists() {
        let favoritesPath = folderPath.appendingPathComponent("config.json")
        guard !FileManager.default.fileExists(atPath: favoritesPath.path) else { return }
        
        let config = Config(favorites: [])
        
        // Encode the Config instance to Data
        let encoder = JSONEncoder()
        if let configData = try? encoder.encode(config) {
            // Create the file with the encoded data
            FileManager.default.createFile(
                atPath: favoritesPath.path,
                contents: configData,
                attributes: nil
            )
        } else {
            // Handle error if encoding fails
            print("Failed to encode config")
        }
    }
    
    func loadConfig() {
        print("Loading config")
        let favoritesPath = folderPath.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: favoritesPath) else { return }
        let decoder = JSONDecoder()
        do {
            config = try decoder.decode(Config.self, from: data)
            self.loadFavorite()

        } catch {
            print("Failed to load favorites: \(error)")
        }
    }
    /// Loads favorite images from config.favorites into self.favoriteImages
    func loadFavorite(){
        if config == nil {return}
        let config = self.config!
        for favorite in config.favorites {
            if let image = NSImage(contentsOfFile: favorite) {
                print("Found favorite image: \(favorite)")
                self.favoriteImages.insert(
                    NamedImage(
                        image: image,
                        url: URL(string: favorite)!
                    )
                )
            }
        }
        print("Loaded \(favoriteImages.count) favorite images)")
    }
    
    func writeConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(config!) else { return }
        let favoritesPath = folderPath.appendingPathComponent("config.json")

        // Ensure the directory exists, create it if not
        let fileManager = FileManager.default
        let directory = favoritesPath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory: \(error)")
                return
            }
        }
        
        // Write the data to the file (this will overwrite if the file exists)
        do {
            try data.write(to: favoritesPath)
            print("Config written successfully to \(favoritesPath.path)")
        } catch {
            print("Failed to write config to file: \(error)")
        }
    }
    
    
    func makeFavorite() {
        favoriteCurrentImage()
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
        let today = Calendar.current.startOfDay(for: Date())
        let lastRunDate = UserDefaults.standard.object(forKey: "LastDailyTaskRunDate") as? Date ?? .distantPast
        return lastRunDate < today
    }

    func markDailyTaskAsRun() {
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: "LastDailyTaskRunDate")
    }

}
