//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI
import AppKit
import ImageIO







// MARK: DailyPicApp
@main
struct DailyPicApp: App {
    // 2 variables to set default focus https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
    
    @ObservedObject var imageManager = GalleryViewModel.getInstance()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let menuIcon: NSImage = {
        let ratio = $0.size.height / $0.size.width
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "Aurora Walls Mono")!)
    
    var body: some Scene {
        MenuBarExtra() {
            // Title
            Text(self.getTitleText())
                .font(.headline)
                .padding(.top, 15)
            if let metadata = imageManager.currentImage?.metadata {
                Text(metadata.title)
                    .font(.subheadline)
            }
            
            if let nextImage = imageManager.revealNextImage {
                RevealNextImageView(revealNextImage: nextImage)
                    .transition(.opacity.combined(with: .scale)) // Add transition effect
                    .animation(.easeInOut(duration: 0.8), value: (imageManager.revealNextImage != nil))
            }            // Image Data
            VStack() {
                if let current_image = imageManager.currentImage {
                    DropdownWithToggles(
                        bingImage: current_image.metadata, image: current_image,
                        imageManager: imageManager
                    )
                    // Image Preview
                    if let loaded_image = current_image.loadNSImage() {
                        Image(nsImage: loaded_image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .shadow(radius: 3)
                            // Adding a tap gesture to open the image in an image viewer
                            .onTapGesture {
                                openInViewer(url: current_image.url)
                            }
                    }
                } else {
                    VStack(alignment: .center) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud")
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: 50, minHeight: 50)
                            .padding(.top, 10)
                        Text("No image available.")
                            .font(.headline)
                            .padding(10)
                        Text("Downloading images from last 7 days...")
                            .font(.headline)
                            .padding(10)
                    }
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .center)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                ImageNavigation(imageManager: imageManager)
                    .scaledToFit()  // make it not overflow the box
                
                QuickActions(imageManager: imageManager)
                    .layoutPriority(2)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 15)
            .frame(width: 350, height: 450)
            .focusScope(mainNamespace)
            .onAppear {
                Task {await BingImageTracker.shared.downloadMissingImages()}
            }
            .focusEffectDisabled(true)
            .onDisappear {
                imageManager.onDisappear();
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }
    
    func getTitleText() -> String {
        let wrap_text = { (date: String) in return "Picture of \(date)" }
        
        guard let image = imageManager.currentImage else {
            // use DateParser for date formatting
            return wrap_text(DateParser.prettyDate(for: Date()))
        }
        return wrap_text(DateParser.prettyDate(for: image.getDate()))
    }
    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func loadPreviousBingImages() {
        Task {
            
            let dates = await BingImageTracker.shared.downloadMissingImages()
            await MainActor.run {
                print("downloaded bing wallpapers from these days: \(dates)")
                
                // save the url of the current image
                let current_image_url = imageManager.currentImage?.url
                
                // reload images
                imageManager.loadImages()
                
                // set index where last picture is now
                if let url = current_image_url {
                    imageManager.setIndexByUrl(url)
                }
            }
        }
    }
}



extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}



