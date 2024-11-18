//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI

struct NamedImage: Hashable, CustomStringConvertible  {
    let image: NSImage
    let url: URL
    
    // Implement the required `==` operator for equality comparison
    static func ==(lhs: NamedImage, rhs: NamedImage) -> Bool {
        return lhs.url.lastPathComponent == rhs.url.lastPathComponent
    }

    // Implement the required `hash(into:)` method
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.lastPathComponent)
    }
    
    // Implement the description property for custom printing
    var description: String {
        return "NamedImage(url: \(url))"
    }
}


class WakeObserver {
    private var onWake: () -> Void
    
    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
    }
    
    @objc private func handleWakeNotification() {
        print("Handle Wake")
        onWake()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}



@main
struct DailyPicApp: App {
    @State var currentNumber: String = "1" // Example state variable
    @StateObject private var imageManager = ImageManager()
    private var wakeObserver: WakeObserver?
    
    init() {
        wakeObserver = WakeObserver { [imageManager] in
            imageManager.runDailyTaskIfNeeded()
        }
        imageManager.runDailyTaskIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra("DailyPic", systemImage: "photo") {
            VStack(alignment: .center) {
                Text("DailyPic Controls")
                    .font(.headline)
                Divider()
                    .padding()
                
                // Image Preview
                if let current_image = imageManager.currentImage {
                    Image(nsImage: current_image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(radius: 3)
                } else {
                    Text("No image available")
                        .padding()
                }
                HStack(spacing: 50) { // Adjust spacing here
                    // Backward Button
                    Button(action: {
                        // Add your backward action here
                        imageManager.showPreviousImage()
                    }) {
                        Image(systemName: "arrow.left") // SF Symbol for icon
                            .font(.title2) // Adjust icon size
                    }
                    //.buttonStyle(.borderless)
                    
                    // Favorite Button
                    Button(action: {imageManager.makeFavorite()}) {
                        Image(
                            systemName: imageManager.isCurrentFavorite() ? "star.fill" : "star"
                        )
                            .foregroundColor(.gray) // Optional: favorite color
                            .font(.title2)
                    }
                    .buttonStyle(.borderless)
                    
                    // Forward Button
                    Button(action: {
                        imageManager.showNextImage()
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                    }
                    //.buttonStyle(.borderless)
                }
                
                Divider()
                
                Button(action: {imageManager.openFolder()}) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                        Text("Open Folder")
                            .font(.body)
                    }
                }
                .buttonStyle(.borderless)
                .scaledToFill()
            }
            .padding(10) // Adds padding to make it look better
            .frame(width: 350) // Adjust width to fit the buttons
            .onAppear {
                imageManager.ensureFolderExists()
                imageManager.loadImages()
                imageManager.runDailyTaskIfNeeded()
            }
        }
        .menuBarExtraStyle(.window)
    }
    

}



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





struct Config: Codable {
    var favorites: Set<String>
}
