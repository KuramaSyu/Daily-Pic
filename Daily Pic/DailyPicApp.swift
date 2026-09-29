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

// Helper to downcast any to concrete for generic MenuContent
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

    /// Mode the user picked from the play menu while a different api was active.
    /// Survives the api switch so the picked mode wins once, then schedule retakes.
    @State private var pendingMode: ImageSelectionMode?

    /// Wall-clock time at which the user's manual override expires.
    /// Set when the user taps a manual api or play-mode; cleared when the
    /// schedule finally fires (api or segment boundary crosses).
    /// While now < this, reconcile is a no-op so the override sticks.
    @State private var manualOverrideUntil: Date?

    /// Tag identifying who flipped the api binding last. onChange reads this
    /// to decide whether to arm the manual-override lock.
    @State private var lastApiChange: ApiChangeSource = .initial

    /// Background reconciler for wake / unlock / app-activate / minute-tick events.
    /// Posts dailyPicReconcileRequest; the menu listens and calls reconcile.
    private let reconciler = ScheduleReconciler()

    init() {
        let schedule = ApiScheduleStore.shared
        let initialApi = schedule.enabled ? schedule.resolve() : .bing
        let deps = AppDependencies(api: initialApi)
        _deps = State(initialValue: deps)
        _api = State(initialValue: initialApi)
        // Seed the singleton stores so settings and quicksettings agree on
        // the active api + auto-apply state at launch.
        DependenciesStore.shared.update(
            imageManager: deps.galleryVM,
            imageTracker: deps.imageTracker
        )
        WallpaperAutoApplyStore.shared.seed(from: deps.galleryVM.config)
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
        // Start background reconciler so wake / unlock / app-activate / minute-tick
        // can drive schedule evaluation without the menu being open.
        reconciler.start()
        appDelegate.attachReconciler(reconciler)
        // Apply the schedule's image-selection segment for the starting API
        // so the first menu open already shows the right image.
        Self.applyInitialImageSelection(deps: deps, schedule: schedule)
    }

    // Run at launch and on every api switch. No-op when schedule disabled
    // or no matching rule with segments.
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
    }

    /// Single entry point that drives the menu from the schedule.
    /// Called on menu open, every minute tick, and on wake / unlock / app-activate events.
    /// `force` bypasses the manual-override lock (used when the user toggles
    /// the schedule on, since enabling the master switch is itself an intent).
    func reconcileWithSchedule(force: Bool = false) {
        let now = Date()
        scheduleStore.recomputeNextChange(now: now)
        guard scheduleStore.enabled else { return }
        // Honour a manual override until the schedule's next planned change.
        if !force, let until = manualOverrideUntil, now < until {
            RuntimeLog.write("reconcile: skipped (manual override until \(until))")
            return
        }
        let rule = scheduleStore.matchingRule(for: now)
        if api != rule.api {
            RuntimeLog.write("reconcile: switch api \(api.rawValue)->\(rule.api.rawValue)")
            // Schedule-driven switch clears the override and tags the source.
            manualOverrideUntil = nil
            lastApiChange = .schedule
            api = rule.api
            return
        }
        deps.galleryVM.applyScheduledImageSelection(
            rule: rule,
            now: now,
            store: ImageSelectionScheduleStore.shared
        )
    }

    /// User tapped one of the play-menu modes. Resolves the matching rule,
    /// switches api if needed, stashes the picked mode so it survives the rebuild.
    /// Sets a manual override so the schedule does not flip back on the next reconcile.
    func applyUserPickedMode(_ mode: ImageSelectionMode) {
        let now = Date()
        let rule = scheduleStore.matchingRule(for: now)
        pendingMode = mode
        manualOverrideUntil = scheduleStore.nextApiChange?.at
        lastApiChange = .user
        if api != rule.api {
            api = rule.api
            return
        }
        // Same api: apply immediately via a synthesised one-segment rule.
        let synthetic = ApiScheduleRule(
            id: rule.id,
            startMinute: rule.startMinute,
            endMinute: rule.endMinute,
            weekdays: rule.weekdays,
            api: api,
            segments: [ImageSelectionSegment(durationMinutes: 60, mode: mode)]
        )
        deps.galleryVM.applyScheduledImageSelection(
            rule: synthetic,
            now: now,
            store: ImageSelectionScheduleStore.shared
        )
        pendingMode = nil
    }

    let menuIcon: NSImage = {
        let ratio = $0.size.width > 0 ? $0.size.height / $0.size.width : 1
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "AuroraWallsMono") ?? NSImage())
    
    var body: some Scene {
        MenuBarExtra() {
            // Hidden minute-tick driver for the API schedule.
            // Does not touch the api binding; manual picks always win.
            ApiScheduleHeartbeat(store: scheduleStore)
            // Custom binding that tags user taps so onChange can arm the
            // manual-override lock. ApiSelection writes through this.
            let userApiBinding = Binding<WallpaperApiEnum>(
                get: { self.api },
                set: { newValue in
                    self.lastApiChange = .user
                    self.api = newValue
                }
            )
            switch deps.api {
            case .bing:
                MenuContent (
                    vm: cast(BingGalleryViewModel.self, deps.galleryVM),
                    api: userApiBinding,
                    menuIcon: menuIcon,
                    imageTracker: deps.imageTracker as! BingImageTracker,
                    applyUserPickedMode: applyUserPickedMode,
                    reconcile: reconcileWithSchedule
                )
            case .osu:
                MenuContent (
                    vm: cast(OsuGalleryViewModel.self, deps.galleryVM),
                    api: userApiBinding,
                    menuIcon: menuIcon,
                    imageTracker: deps.imageTracker as! OsuImageTracker,
                    applyUserPickedMode: applyUserPickedMode,
                    reconcile: reconcileWithSchedule
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
            // Refresh the singletons so settings can reach the new tracker/vm.
            DependenciesStore.shared.update(
                imageManager: deps.galleryVM,
                imageTracker: deps.imageTracker
            )
            WallpaperAutoApplyStore.shared.seed(from: deps.galleryVM.config)
            appDelegate.reinjectDepencies(vm: deps.galleryVM, imageTracker: deps.imageTracker)

            print("reload from \(#function)")
            deps.galleryVM.selfLoadImages()
            deps.galleryVM.restoreLastUsedImageOrFallback()
            // If this api flip came from a user tap (ApiSelection button or
            // play-menu mode on a different api), arm the manual override so
            // reconcile does not bounce back on the next wake / minute-tick.
            // Schedule-driven flips tag themselves .schedule before mutating.
            if lastApiChange == .user {
                manualOverrideUntil = scheduleStore.nextApiChange?.at
            }
            // Honour a stashed pendingMode so a play-menu pick survives the api
            // switch; the schedule takes back over at the next segment boundary.
            if let mode = pendingMode {
                let synthetic = ApiScheduleRule(
                    api: newValue,
                    segments: [ImageSelectionSegment(durationMinutes: 60, mode: mode)]
                )
                deps.galleryVM.applyScheduledImageSelection(
                    rule: synthetic,
                    now: Date(),
                    store: ImageSelectionScheduleStore.shared
                )
                pendingMode = nil
            } else {
                Self.applyInitialImageSelection(deps: deps, schedule: scheduleStore)
            }
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

// Who flipped the api binding last. Used by onChange to decide whether to
// arm the manual-override lock on the schedule.
enum ApiChangeSource {
    case initial
    case user
    case schedule
}



extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}



