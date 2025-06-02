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
    
    @ObservedObject var galleryView = GalleryViewModel.shared
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
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
            ZStack {
                // title
                VStack {
                    Text(self.getTitleText())
                        .font(.headline)
                        .padding(.top, 15)
                    if let title = galleryView.currentImage?.getTitle() {
                        Text(title)
                            .font(.subheadline)
                    }
                }
                
                // Top-right gear button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            SettingsWindowController.shared.showSettings()
                        }) {
                            Image(systemName: "gearshape")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .padding(6)
                        }
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(PlainButtonStyle()) // Prevents default macOS blue highlight
                    }
                    .padding(6)
                    Spacer()
                }
            }

            
            if let nextImage = galleryView.revealNextImage {
                RevealNextImageView(revealNextImage: nextImage)
                    .transition(.opacity.combined(with: .scale)) // Add transition effect
                    .animation(.easeInOut(duration: 0.8), value: (galleryView.revealNextImage != nil))
            }            // Image Data
            VStack() {
                if let current_image = galleryView.currentImage {
                    DropdownWithToggles(
                        bingImage: current_image.metadata, image: current_image,
                        imageManager: galleryView
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
                
                ImageNavigation(imageManager: galleryView)
                    .scaledToFit()  // make it not overflow the box
                ApiSelection()
                    .scaledToFit()
                QuickActions(imageManager: galleryView)
                    .layoutPriority(2)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 15)
            .frame(width: 350, height: 450)
            .focusScope(mainNamespace)
            .onAppear {
                Task {await self.galleryView.imageTracker.downloadMissingImages(from: nil, reloadImages: true)}
            }
            .focusEffectDisabled(true)
            .onDisappear {
                galleryView.onDisappear();
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }
    
    func getTitleText() -> String {
        let wrap_text = { (date: String) in return "Picture of \(date)" }
        
        guard let image = galleryView.currentImage else {
            // use DateParser for date formatting
            return wrap_text(DateParser.prettyDate(for: Date()))
        }
        return image.getSubtitle();
    }
    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func loadPreviousBingImages() {
        Task {
            
            let dates = await self.galleryView.imageTracker.downloadMissingImages(from: nil, reloadImages: false)
            await MainActor.run {
                print("downloaded bing wallpapers from these days: \(dates)")
                
                // save the url of the current image
                let current_image_url = galleryView.currentImage?.url
                
                // reload images
                galleryView.selfLoadImages()
                
                // set index where last picture is now
                if let url = current_image_url {
                    galleryView.setIndexByUrl(url)
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



