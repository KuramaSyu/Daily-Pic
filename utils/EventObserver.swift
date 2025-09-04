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
    private(set) var deps: AppDependencies!
    var screenListener: ScreenStateListener?
    var workspaceListener: WorkspaceStateListener?

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
    

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is called when the app is first launched
        screenListener = ScreenStateListener(vm: deps.makeGalleryVM(), imageTracker: imageTracker)
        workspaceListener = WorkspaceStateListener(galleryView: galleryView, imageTracker: imageTracker)
        Task {
            await screenListener?.performBackgroundTask()
        }
    }

    func applicationDidEnterBackground(_ notification: Notification) {
        //self.galleryView.onDisappear()
    }
    
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
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
            self?.handleScreenOn()
        }
    }
    
    func setupSystemWakeListener() {
        print("Setting up system wake listener at: \(Date())")
        systemWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }
    }
    
    @objc func handleScreenOn() {
        print("Screen turned on at: \(Date()) - Update current picture")
        performTaskOnWake()
    }
    
    @objc func handleSystemWake() {
        print("System woke up at: \(Date()) - Update current picture")
        performTaskOnWake()
    }
    
    private func performTaskOnWake() {
        Task {
            await performBackgroundTask()
        }
    }
    
    public func performBackgroundTask() async {
        Swift.print("executing performBackgroundTask")
        await self.vm?.revealNextImage?.removeIfOverdue()

        do {
            let _ = try await self.imageTracker!.downloadMissingImages(from: nil, reloadImages: false)

        } catch let error {
            Swift.print("Background task failed with error: \(error)")
        }
        Swift.print("finished performBackgroundTask")
    }
    
    deinit {
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
            self?.handleWorkspaceChange()
        }
    }
    
    @objc func handleWorkspaceChange() {
        print("Workspace (virtual desktop) changed at: \(Date()) - Update current picture")
        guard let wallpaper = self.galleryView!.currentImage else { return }
        WallpaperHandler().setWallpaper(image: wallpaper.url)
    }
    
    deinit {
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
    
    static func calculateTriggerInterval() -> TimeInterval {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        
        // Get the next minute's start time
        guard let nextMinute = calendar.date(byAdding: .minute, value: 5, to: now.truncateToMinute()) else {
            // Fallback to 5-minute interval if calculation fails
            return 5 * 60
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
    
    // Function to be called when the trigger fires
    func revealImage() async {
        // let _ = await ImageManager.shared.downloadMissingImages()
        await MainActor.run {
            print("Image revealed! Date: \(String(describing: imageDate))")
            self.vm.revealNextImage = nil
            self.vm.selfLoadImages()
            // check if imageDate is today
            if Calendar.current.isDate(imageDate!, inSameDayAs: Date()) {
                self.vm.showLastImage()
            }
            
        }
    }
    
    func deleteTrigger() async {
        triggerStarted = false
        await MainActor.run {
            print("cancel reveal and del revealNextImage")
            self.vm.revealNextImage = nil
        }
    }

    // Async trigger logic using Task.sleep
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
            await revealImage()
        } catch {
            print("Task was cancelled or failed: \(error)")
        }
    }
    
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

