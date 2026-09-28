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
    @ObservedObject private var scheduleStore = ApiScheduleStore.shared


    init() {
        let schedule = ApiScheduleStore.shared
        let initialApi = schedule.enabled ? schedule.resolve() : .bing
        let deps = AppDependencies(api: initialApi)
        _deps = State(initialValue: deps)
        _api = State(initialValue: initialApi)
        appDelegate.reinjectDepencies(vm: deps.galleryVM, imageTracker: deps.imageTracker)
        RuntimeLog.write("app init api=\(initialApi) scheduleEnabled=\(schedule.enabled)")
        RuntimeLog.startMemorySampler(interval: 60)
        // Register an evictor that drops idle NSImage caches on the active
        // gallery VM. Runs on the MainActor every 60 s so the cache cannot
        // grow without bound between explicit navigations.
        RuntimeLog.registerEvictor { [deps] in
            deps.galleryVM.evictIdleCaches(ttl: 30)
        }
        RuntimeLog.startEvictor(interval: 60)
        // Apply the schedule's image-selection segment for the starting API
        // so the very first menu open already shows the right image. Falls
        // through to the existing "last used" fallback when no segment
        // matches (e.g. schedule disabled or rule has no segments).
        Self.applyInitialImageSelection(deps: deps, schedule: schedule)
    }

    // Run once at launch (and again when the user switches API) so the
    // gallery VM honours the schedule's image-selection segment for the
    // current rule. No-ops when the schedule is disabled or has no
    // matching rule with image segments configured.
    private static func applyInitialImageSelection(
        deps: AppDependencies,
        schedule: ApiScheduleStore
    ) {
        let now = Date()
        let rule = schedule.matchingRule(for: now)
        deps.galleryVM.applyScheduledImageSelection(
            rule: rule,
            now: now,
            store: ImageSelectionScheduleStore.shared
        )
        // If no segment matched (or rule has no segments), leave the VM
        // where restoreLastUsedImageOrFallback already placed it during
        // AppDependencies init. No additional call needed.
    }

    let menuIcon: NSImage = {
        let ratio = $0.size.width > 0 ? $0.size.height / $0.size.width : 1
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "AuroraWallsMono") ?? NSImage())
    
    var body: some Scene {
        MenuBarExtra() {
            // Hidden minute-tick driver for the API schedule. Recomputes
            // the store's nextChange every minute so the banner in the
            // menu shows an accurate countdown. Does not touch the api
            // binding: manual picks always win.
            ApiScheduleHeartbeat(store: scheduleStore)
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
            deps.galleryVM.restoreLastUsedImageOrFallback()
            Self.applyInitialImageSelection(deps: deps, schedule: scheduleStore)
        }

    }
    

    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func updateImage() {
        Task {
            _ = try await deps.imageTracker.downloadMissingImages(from: nil, reloadImages: false)
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



