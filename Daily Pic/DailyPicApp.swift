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
    static let defaultValue: AppDependencies = AppDependencies(api: WallpaperApiEnum.bing)
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
    
    @State private var deps: AppDependencies
    @State private var api: WallpaperApiEnum


    init() {
        let initialApi = WallpaperApiEnum.bing
        let deps = AppDependencies(api: initialApi)
        _deps = State(initialValue: deps)
        _api = State(initialValue: initialApi)
    }

    let menuIcon: NSImage = {
        let ratio = $0.size.height / $0.size.width
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "AuroraWallsMono")!)
    
    var body: some Scene {
        MenuBarExtra() {
            switch deps.api {
            case .bing:
                MenuContent (
                    vm: cast(BingGalleryViewModel.self, deps.galleryVM),
                    api: $api,
                    menuIcon: menuIcon,
                    imageTracker: deps.imageTracker as! BingImageTracker
                )
            case .osu:
                MenuContent (
                    vm: cast(OsuGalleryViewModel.self, deps.galleryVM),
                    api: $api,
                    menuIcon: menuIcon,
                    imageTracker: deps.imageTracker as! OsuImageTracker
                )
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
        .environment(\.dependencies, deps)
        .onChange(of: api, initial: true) { _, newValue in
            let newDeps = AppDependencies(api: newValue)
            self.deps = newDeps
            appDelegate.reinjectDepencies(vm: deps.galleryVM, imageTracker: deps.imageTracker)
            
            print("reload from \(#function)")
            deps.galleryVM.selfLoadImages()
            deps.galleryVM.showLastImage()
        }
        
    }
    

    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func updateImage() {
        Task {
            let dates = try await deps.imageTracker.downloadMissingImages(from: nil, reloadImages: false)
            await MainActor.run {
                print("reload from \(#function)")
                // reload images
                deps.galleryVM.selfLoadImages()
            }
        }
    }
}



extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}



