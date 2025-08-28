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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var api: WallpaperApiEnum = .bing
    @ObservedObject var galleryView = BingGalleryViewModel.shared


    let menuIcon: NSImage = {
        let ratio = $0.size.height / $0.size.width
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "Aurora Walls Mono")!)
    
    var body: some Scene {
        MenuBarExtra() {
            switch api {
            case .bing:
                MenuContent (
                    vm: BingGalleryViewModel.shared, api: $api, menuIcon: menuIcon
                )
            case .osu:
                MenuContent (
                    vm: OsuGalleryViewModel.shared, api: $api, menuIcon: menuIcon
                )
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
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



