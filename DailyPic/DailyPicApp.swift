//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI

@main
struct DailyPicApp: App {
    @State var currentNumber: String = "1" // Example state variable
    @StateObject private var imageManager = ImageManager()

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
                        Image(systemName: "star.fill") // SF Symbol for icon
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
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Image Manager
class ImageManager: ObservableObject {
    @Published var images: [NSImage] = []
    @Published var currentIndex: Int = 0

    private let folderPath: URL

    // Computed property to get the current image
    var currentImage: NSImage? {
        guard !images.isEmpty, currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex]
    }

    init() {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        folderPath = documentsPath.appendingPathComponent("DailyPic")

        ensureFolderExists()
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

            images = imageFiles.compactMap { NSImage(contentsOf: $0) }
            currentIndex = 0 // Reset to the first image
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
    }
    
    // opens the picture folder
    func openFolder() {
        NSWorkspace.shared.open(folderPath)
    }
}

struct Config: Codable {
    let favorites: [String]
}
