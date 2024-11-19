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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLaunchNotification),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
    }
    
    @objc private func handleWakeNotification() {
        print("Handle Wake")
        onWake()
    }
    
    @objc private func handleLaunchNotification() {
        print("Handle Launch")
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
    @State private var wakeObserver: WakeObserver?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("called init")
//        self.wakeObserver = WakeObserver { [imageManager] in
//            imageManager.runDailyTaskIfNeeded()
//        }
//        imageManager.runDailyTaskIfNeeded()

    }

    var body: some Scene {
        MenuBarExtra("DailyPic", systemImage: "photo") {
            VStack(alignment: .center) {
                Text("DailyPic Controls")
                    .font(.headline)
                    .padding(3)
                Divider()
                    .padding(.bottom, 3)
                
                // Image Preview
                if let current_image = imageManager.currentImage {
                    Image(nsImage: current_image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(radius: 3)
                        .layoutPriority(2)
                    
                } else {
                    Text("No image available")
                        .padding()
                        
                }
                HStack(spacing: 3) {
                    
                    // Backward Button
                    Button(action: {
                        imageManager.showPreviousImage()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .layoutPriority(1)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                    
                    
                    // Favorite Button
                    Button(action: {imageManager.makeFavorite()}) {
                        Image(
                            systemName: imageManager.isCurrentFavorite() ? "star.fill" : "star"
                        )
                        .frame(maxWidth: .infinity, minHeight: 50)
                            .font(.title2)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .buttonStyle(.borderless)
                    .layoutPriority(1)
                    .hoverEffect()
                    
                    // Forward Button
                    Button(action: {
                        imageManager.showNextImage()
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .layoutPriority(1)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .scaledToFill()
                //.frame(width: .infinity)
                
                Divider()
                
                // Wallpaper Button
                Button(action: {
                    if let url = imageManager.currentImageUrl {
                        WallpaperHandler().setWallpaper(image: url)
                    }
                }) { HStack {
                        Image(systemName: "photo.tv")
                            .font(.title2)
                            .padding(.horizontal, 20)
                        Text("Set as Wallpaper")
                            .font(.body)
                            .scaledToFill()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(2)
                .hoverEffect()
                
                // Open Folder
                Button(action: {imageManager.openFolder()}) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .padding(.horizontal, 20)
                        Text("Open Folder")
                            .font(.body)
                            .scaledToFill()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(2)
                .hoverEffect()
            }
            .padding(10) // Adds padding to make it look better
            .frame(width: 350, height: 400) // Adjust width to fit the buttons
            .onAppear {
                imageManager.ensureFolderExists()
                imageManager.loadImages()
                imageManager.runDailyTaskIfNeeded()
            }
            .scaledToFill()
        }
        .menuBarExtraStyle(.window)
    }
    

}







struct Config: Codable {
    var favorites: Set<String>
}
