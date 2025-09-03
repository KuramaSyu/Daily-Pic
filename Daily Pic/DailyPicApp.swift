//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI
import AppKit
import ImageIO



private struct DependencyKey: EnvironmentKey {
    static let defaultValue: AppDependencies = .live()
}


extension EnvironmentValues {
    var dependencies: AppDependencies {
        get {
            self[DependencyKey.self]
        } set {
            self[DependencyKey.self] = newValue
        }
    }
}

// Helper to downcast `any` to concrete for generic MenuContent
private func cast<T>(_ _: T.Type, _ value: any GalleryViewModelProtocol) -> T {
    value as! T
}


// MARK: DailyPicApp
@main
struct DailyPicApp: App {
    // 2 variables to set default focus https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)
    
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let deps: AppDependencies
    
    // Hold the current instances you want to reuse in the menu/view layer
    @State private var api: WallpaperApiEnum
    @State private var galleryVM: any GalleryViewModelProtocol
    @State private var imageTracker: any ImageTrackerProtocol

    init() {
        let deps = AppDependencies.live()
        self.deps = deps
        let initialApi = WallpaperApiEnum.bing
        _api = State(initialValue: initialApi)
        _galleryVM = State(initialValue: deps.makeGalleryVM(initialApi))
        _imageTracker = State(initialValue: deps.makeImageTracker(initialApi))
    }

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
                    vm: cast(BingGalleryViewModel.self, galleryVM),
                    api: $api,
                    menuIcon: menuIcon,
                    imageTracker: imageTracker,
                )
            case .osu:
                MenuContent (
                    vm: cast(OsuGalleryViewModel.self, galleryVM),
                    api: $api,
                    menuIcon: menuIcon,
                    imageTracker: imageTracker
                )
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
        .environment(\.dependencies, deps)
        .onChange(of: api, initial: true) {
            appDelegate.galleryView = galleryVM
            
        }
        .onChange(of: api, initial: true) { _, newValue in
            galleryVM = deps.makeGalleryVM(newValue)
            imageTracker = deps.makeImageTracker(newValue)
            appDelegate.galleryView = galleryVM
        }
        
    }
    

    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func updateImage() {
        Task {
            let dates = try await self.imageTracker.downloadMissingImages(from: nil, reloadImages: false)
            await MainActor.run {
                print("downloaded bing wallpapers from these days: \(dates)")
                // reload images
                galleryVM.selfLoadImages()
            }
        }
    }
}



extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}



