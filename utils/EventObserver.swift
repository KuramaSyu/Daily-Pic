//
//  EventObserver.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI
import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var screenListener: ScreenStateListener?
    var workspaceListener: WorkspaceStateListener?
    var reconciler: ScheduleReconciler?

    // Injected from the App; propagate updates to children
    var galleryView: (any GalleryViewModelProtocol)? {
        didSet {
            screenListener?.vm = galleryView
            workspaceListener?.galleryView = galleryView
        }
    }

    var imageTracker: (any ImageTrackerProtocol)? {
        didSet {
            screenListener?.imageTracker = imageTracker
            workspaceListener?.imageTracker = imageTracker
        }
    }

    /// DailyPicApp.init() calls this. The reconciler posts the reconcile
    /// notification; the app listens on the menu View.
    func attachReconciler(_ reconciler: ScheduleReconciler) {
        self.reconciler = reconciler
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is called when the app is first launched
        screenListener = ScreenStateListener(vm: galleryView, imageTracker: imageTracker)
        workspaceListener = WorkspaceStateListener(galleryView: galleryView, imageTracker: imageTracker)
        Task {
            await screenListener?.performBackgroundTask()
        }
    }

    func reinjectDepencies(
        vm: any GalleryViewModelProtocol,
        imageTracker: any ImageTrackerProtocol,
    ) {
        self.galleryView = vm
        self.imageTracker = imageTracker
        screenListener?.vm = vm
        screenListener?.imageTracker = imageTracker
        workspaceListener?.galleryView = vm
        workspaceListener?.imageTracker = imageTracker
    }

    func applicationDidEnterBackground(_ notification: Notification) {
        //self.galleryView.onDisappear()
    }

    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
}

/// Notification posted by ScheduleReconciler when a wake / unlock /
/// app-activate / minute-tick event should re-evaluate the schedule.
extension Notification.Name {
    static let dailyPicReconcileRequest = Notification.Name("DailyPicReconcileRequest")
}



class ScreenStateListener {
    private var screenActivationObserver: NSObjectProtocol?
    private var systemWakeObserver: NSObjectProtocol?
    var vm: (any GalleryViewModelProtocol)?
    var imageTracker: (any ImageTrackerProtocol)?
    
    init(vm: (any GalleryViewModelProtocol)?, imageTracker: (any ImageTrackerProtocol)?) {
        self.vm = vm
        self.imageTracker = imageTracker
        setupScreenOnListener()
        setupSystemWakeListener()
    }
    
    func setupScreenOnListener() {
        print("Setting up screen on listener at: \(Date())")
        screenActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleWakeTask()
        }
    }

    func setupSystemWakeListener() {
        print("Setting up system wake listener at: \(Date())")
        systemWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleWakeTask()
        }
    }

    private var pendingWakeTask: Task<Void, Never>?
    private let wakeDebounceInterval: TimeInterval = 5.0

    private func scheduleWakeTask() {
        pendingWakeTask?.cancel()
        pendingWakeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.wakeDebounceInterval ?? 5.0 * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.performBackgroundTask()
        }
    }

    @objc func handleScreenOn() {
        print("Screen turned on at: \(Date()) - Update current picture")
        scheduleWakeTask()
    }

    @objc func handleSystemWake() {
        print("System woke up at: \(Date()) - Update current picture")
        scheduleWakeTask()
    }

    private func performTaskOnWake() {
        scheduleWakeTask()
    }
    
    public func performBackgroundTask() async {
        Swift.print("executing performBackgroundTask")
        RuntimeLog.write("performBackgroundTask start")
        await self.vm?.revealNextImage?.removeIfOverdue()

        guard let imageTracker = self.imageTracker else {
            RuntimeLog.write("performBackgroundTask skipped: imageTracker nil")
            Swift.print("background task skipped: imageTracker not injected")
            return
        }

        do {
            let _ = try await imageTracker.downloadMissingImages(from: nil, reloadImages: false)

        } catch let error {
            Swift.print("Background task failed with error: \(error)")
            RuntimeLog.write("performBackgroundTask error: \(error)")
        }
        // Drop any cached bitmaps that have not been touched in a while.
        // This is the safety net that prevents the NSImage cache from
        // growing without bound when the user is idle or locked.
        self.vm?.evictIdleCaches(ttl: 30)
        RuntimeLog.write("performBackgroundTask end")
        Swift.print("finished performBackgroundTask")
    }
    
    deinit {
        pendingWakeTask?.cancel()
        if let screenObserver = screenActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(screenObserver)
        }
        if let wakeObserver = systemWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}




class WorkspaceStateListener {
    private var workspaceChangeObserver: NSObjectProtocol?
    var galleryView: (any GalleryViewModelProtocol)?
    var imageTracker: (any ImageTrackerProtocol)?
    private var pendingTask: Task<Void, Never>?
    /// Drop duplicate wallpaper re-apply requests within this window.
    /// macOS bursts activeSpaceDidChange events when waking or animating desktops,
    /// each one re-decodes the current wallpaper NSImage.
    private let debounceInterval: TimeInterval = 2.0
    private var lastApplyURL: URL?
    private var lastApplyAt: Date = .distantPast

    init(galleryView: (any GalleryViewModelProtocol)?, imageTracker: (any ImageTrackerProtocol)?) {
        self.galleryView = galleryView
        self.imageTracker = imageTracker
        setupWorkspaceChangeListener()
    }
    func setupWorkspaceChangeListener() {
        print("Setting up workspace change listener at: \(Date())")
        workspaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleWorkspaceChange()
        }
    }

    private func scheduleWorkspaceChange() {
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            guard let self else { return }
            // coalesce burst events into a single apply
            try? await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
            if Task.isCancelled { return }
            await self.handleWorkspaceChange()
        }
    }

    @objc func handleWorkspaceChange() async {
        let now = Date()
        RuntimeLog.write("workspace change fired")
        guard let wallpaper = self.galleryView?.currentImage else {
            RuntimeLog.write("workspace change skipped: no currentImage")
            return
        }
        // Skip if we applied this exact URL very recently.
        if lastApplyURL == wallpaper.url, now.timeIntervalSince(lastApplyAt) < debounceInterval {
            RuntimeLog.write("workspace change skipped: dedup \(wallpaper.url.lastPathComponent)")
            return
        }
        lastApplyURL = wallpaper.url
        lastApplyAt = now
        print("Workspace (virtual desktop) changed at: \(now) - Update current picture")
        await WallpaperHandler().setWallpaper(image: wallpaper.url)
    }

    deinit {
        pendingTask?.cancel()
        if let observer = workspaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}



// Optional extension to help with minute truncation
extension Date {
    func truncateToMinute() -> Date {
        /// returns a date, which strips everyting after the minute eg
        /// 51:43 -> 51:00
        let calendar = Calendar.autoupdatingCurrent
        return calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)) ?? self
    }
}


public class RevealNextImageViewModel: ObservableObject {
    let hideLastImage: Bool
    @Published var at: Date?
    let imageUrl: URL?
    let imageDate: Date?
    var triggerStarted: Bool
    var isPictureDownloaded: Bool = false
    var downloadComplete: Bool = false
    var nextTry: Date? = nil
    var vm: any GalleryViewModelProtocol
    @Published var viewInfoMessage: String?
    
    init (revealNextImageAt: Date, url: URL? = nil, date: Date? = nil, vm: any GalleryViewModelProtocol) {
        self.vm = vm
        self.hideLastImage = true
        self.at = revealNextImageAt
        self.imageUrl = url
        self.imageDate = date
        self.triggerStarted = false
    }

    /// This reveals an image directly, if the reveal time `self.at` is already overdue.
    /// This could be the case, when the system was at sleep when image should have been revealed.
    ///
    /// # Note:
    /// UI-impact
    func removeIfOverdue() async {
        if self.at == nil { return }
        if Date() > self.at! {
            print("removed overdue timer")
            await revealImage()
        } else {
            // restart await
            print("restarted trigger")
            await self.startTrigger()
        }
    }
    
    /// calculates time (as interval) when the image should be revealed
    static func calculateTriggerInterval() -> TimeInterval {
        let REVEAL_IN_SECONDS_DURATION = 2*60
        
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        
        // get the time in now + REVEAL_IN_SECONDS_DURATION, but round down to the start of minute
        guard let nextMinute = calendar.date(
            byAdding: .minute,
            value: REVEAL_IN_SECONDS_DURATION / 60,
            to: now.truncateToMinute()
        ) else {
            // Fallback to 5-minute interval if calculation fails
            return TimeInterval(REVEAL_IN_SECONDS_DURATION)
        }
        
        // Calculate the interval to the exact minute change
        let interval = nextMinute.timeIntervalSince(now)
        
        return interval
    }
    
    static func new(date: Date, vm: any GalleryViewModelProtocol) -> RevealNextImageViewModel {
        let interval = calculateTriggerInterval()
        let self_ = RevealNextImageViewModel(revealNextImageAt: Date(timeIntervalSinceNow: interval), date: date, vm: vm)
        return self_
    }
    
    /// whether or not this image was revealed already
    private func wasRevealedAlready() -> Bool {
        return vm.revealNextImage == nil
    }
    
    /// reveals the image, triggers reload of images and triggers to show the last image
    /// IF it wasn't already updated
    func revealImage() async {
        await MainActor.run {
            
            // check if already revealed
            if self.wasRevealedAlready() {
                print("Seems like image was revealed already. Hence it will be cancelled.")
                return
            }
            
            // reveal if the image is from today (older images could be downloaded too)
            print("Image revealed! Date: \(String(describing: imageDate))")
            self.cancelTrigger()
            self.vm.selfLoadImages()
            if Calendar.current.isDate(imageDate!, inSameDayAs: Date()) {
                self.vm.showLastImage()
            }
        }
    }
    
    /// cancels the trigger async within MainActor
    func deleteTrigger() async {
        await MainActor.run {
            print("cancel reveal and del revealNextImage")
            self.cancelTrigger()
        }
    }

    /// Async trigger logic using Task.sleep
    func startTrigger() async {
        if triggerStarted == true {
            print("trigger started - return")
            return
        }

        let interval = RevealNextImageViewModel.calculateTriggerInterval()
        await MainActor.run {
            triggerStarted = true
            self.at = Date(timeIntervalSinceNow: interval)
        }

        let timeInterval = at!.timeIntervalSinceNow
        print("Reveal next image in \(timeInterval) seconds")
        guard timeInterval > 0 else {
            await revealImage() // Call immediately if the time has passed
            return
        }

        do {
            // Sleep for the calculated time in nanoseconds
            try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
            if Task.isCancelled { return }
            await revealImage()
        } catch {
            print("Task was cancelled or failed: \(error)")
        }
    }
    
    /// Set vm to nil and triggerStarted to false
    func cancelTrigger() {
        triggerStarted = false
        self.vm.revealNextImage = nil
    }
    
}

// A SwiftUI View for displaying the reveal time
struct RevealNextImageView: View {
    @ObservedObject var revealNextImage: RevealNextImageViewModel
    @State private var displayText: String? = nil
    let vm: any GalleryViewModelProtocol

    // Expose a setter to update the text from external sources
    func setInfo(_ newText: String) {
        DispatchQueue.main.async {
            self.displayText = newText
        }
    }
    
    // Formatter for displaying time
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
    let formatToHourMinute: (Date) -> String = { date in
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // State variable to control visibility
    @State private var isVisible: Bool = false

    var body: some View {
        HStack{VStack {
            if isVisible {
                
                if let text = revealNextImage.viewInfoMessage {
                    Text(text)
                        .font(.footnote)
                }
                // Semi-transparent text box
                HStack {
                    if revealNextImage.at != nil {
                        Text("Reveal next at \(formatToHourMinute(revealNextImage.at!))")
                            .font(.footnote)
                        Image(systemName: "xmark.circle")
                            .font(.title2)
                            .onTapGesture {
                                // animate disappear
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    isVisible = false
                                }
                                
                                // cancel trigger, reload & show last image
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    revealNextImage.cancelTrigger()
                                    self.vm.selfLoadImages()
                                    self.vm.showLastImage()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)  // padding from last toggle to bottom
        .padding(.horizontal, 10)  // padding at left for >
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .contentShape(Rectangle()) // Makes the entire label tappable
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                isVisible = true
            }
        }
    }
}

