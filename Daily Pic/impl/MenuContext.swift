import SwiftUI

struct MenuContent<VM: GalleryViewModelProtocol, IM: ImageTrackerProtocol>: View {
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
    @ObservedObject var vm: VM
    @Binding var api: WallpaperApiEnum
    let menuIcon: NSImage
    let imageTracker: IM
    /// Called when the user picks an image-selection mode from the play menu.
    /// The app owns this so it can switch api and carry the picked mode across the rebuild.
    let applyUserPickedMode: (ImageSelectionMode) -> Void
    /// Brings the menu into sync with the schedule on wake / unlock / activate / minute-tick.
    /// `force` bypasses the manual-override lock (used by the schedule enable toggle).
    let reconcile: (Bool) -> Void
    /// Drives the dynamic accent color derived from the current wallpaper.
    @ObservedObject private var accentStore = AccentColorStore.shared

    var body: some View {
        Group {
        ZStack {
            // Image-selection heartbeat: every minute, ask the VM to apply
            // the schedule's current segment. Same pattern as
            // ApiScheduleHeartbeat -- lives inside a View, not a Scene,
            // because .onReceive / .task aren't available on MenuBarExtra.
            ImageSelectionHeartbeat(vm: vm)
            // title
            VStack {
                Text(getTitleText())
                    .font(.headline)
                    .padding(.top, 15)
                if let title = vm.currentImage?.getTitle() {
                    Text(title).font(.subheadline)
                }
            }

            // settings + info icons on top right
            VStack {
                HStack(spacing: 6) {
                    Spacer()
                    InfoPopover(log: InfoLog.shared)
                    Button {
                        SettingsWindowController.shared.showSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(6)
                    }
                    .accentHover()
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(6)
                Spacer()
            }
        }

        // optional image reveal message
        if let nextImage = vm.revealNextImage {
            RevealNextImageView(revealNextImage: nextImage, vm: self.vm)
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.8), value: (vm.revealNextImage != nil))
        }

        // the image or DL-screen if no image is there
        // and the image navigation
        // and quick action drop down
        VStack {
            // image display
            if let currentImage = vm.currentImage {
                DropdownWithToggles(
                    image: currentImage,
                    imageManager: vm
                )
                if let loaded = currentImage.loadNSImage() {
                    Image(nsImage: loaded)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(radius: 3)
                        .onTapGesture { openInViewer(url: currentImage.url) }
                }
            } else {
                // DL-display
                VStack(alignment: .center) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 50, minHeight: 50)
                        .padding(.top, 10)
                    Text("No image available.").font(.headline).padding(10)
                    Text("Downloading images from last 7 days...").font(.headline).padding(10)
                }
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .center)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }

            // image navigation buttons
            ImageNavigation(imageManager: vm).scaledToFit()
            
            // quick action menu
            QuickActions(
                imageManager: vm,
                imageTracker: imageTracker,
                api: $api,
                applyUserPickedMode: applyUserPickedMode
            )
                .layoutPriority(2)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 15)
        .frame(width: 350, height: 450)
        .focusScope(mainNamespace)
        .onAppear {
            // Reconcile when the menu opens so the schedule is honoured immediately.
            // First tracker download also fires here (initial mount).
            reconcile(false)
            let tracker = imageTracker
            Task { try await tracker.downloadMissingImages(from: nil, reloadImages: true) }
        }
        // Subscribe here because Scene does not expose onReceive.
        // Posts come from ScheduleReconciler and the enable toggle.
        .onReceive(NotificationCenter.default.publisher(for: .dailyPicReconcileRequest)) { note in
            // The enable toggle posts reason=scheduleToggle and explicitly
            // wants to snap to the schedule, bypassing any manual override.
            let reason = note.userInfo?["reason"] as? String
            reconcile(reason == "scheduleToggle")
        }
        // api is the proxy for tracker swap since ImageTrackerProtocol is not Equatable.
        // Every api change (manual or schedule-driven) rebuilds deps and swaps the tracker.
        .onChange(of: api) { _, _ in
            let tracker = imageTracker
            Task { try await tracker.downloadMissingImages(from: nil, reloadImages: true) }
        }
        // Sample the current image whenever it flips so the menu's accent
        // color tracks the wallpaper. initial: true covers the first open.
        .onChange(of: vm.currentImage?.url, initial: true) { _, newURL in
            accentStore.update(from: vm.currentImage?.loadNSImage(), url: newURL)
        }
        .focusEffectDisabled(true)
        }
        .tint(accentStore.color)
    }

    private func getTitleText() -> String {
        let wrap = { (date: String) in "Picture of \(date)" }
        guard let image = vm.currentImage else {
            return wrap(DateParser.prettyDate(for: Date()))
        }
        return image.getSubtitle()
    }

    private func openInViewer(url: URL) { NSWorkspace.shared.open(url) }
}

// Hidden view that ticks every minute and asks the gallery VM to apply
// the schedule's current image-selection segment. Same pattern as
// ApiScheduleHeartbeat: must live inside a View (not a Scene) because
// .task isn't available on MenuBarExtra. Renders nothing visible.
struct ImageSelectionHeartbeat<VM: GalleryViewModelProtocol>: View {
    @ObservedObject private var scheduleStore = ApiScheduleStore.shared
    @ObservedObject private var imageStore = ImageSelectionScheduleStore.shared
    let vm: VM

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                while !Task.isCancelled {
                    tick()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            .onChange(of: scheduleStore.rules) { _, _ in tick() }
            .onChange(of: imageStore.randomFavoritesOnly) { _, _ in tick() }
    }

    private func tick() {
        let now = Date()
        let rule = scheduleStore.matchingRule(for: now)
        vm.applyScheduledImageSelection(
            rule: rule,
            now: now,
            store: imageStore
        )
    }
}
