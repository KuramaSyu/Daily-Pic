//
//  EventObserver.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//
import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var screenListener: ScreenStateListener?
    var workspaceListener: WorkspaceStateListener?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is called when the app is first launched
        screenListener = ScreenStateListener()
        workspaceListener = WorkspaceStateListener()
        Task {
            await screenListener?.performBackgroundTask()
        }
        
    }

    func applicationDidEnterBackground(_ notification: Notification) {
        ImageManager.shared.onDisappear()
    }
    
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
}



class ScreenStateListener {
    private var screenActivationObserver: NSObjectProtocol?
    private var systemWakeObserver: NSObjectProtocol?
    
    init() {
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
        // Your existing background task logic
        Swift.print("executing performBackgroundTask")
        var today_is_missing = false
        await ImageManager.shared.revealNextImage?.removeIfOverdue()
        await MainActor.run {
            if ImageManager.shared.revealNextImage != nil {
                print("Cancel performBackgroundTask, revealNextImage already set")
                return
            }
            ImageManager.shared.loadImages()
        }
        
        let dates = ImageManager.shared.getMissingDates()
        let cal = Calendar.autoupdatingCurrent
        for date in dates {
            if cal.isDateInToday(date) {
                today_is_missing = true
            }
        }
        
        if !today_is_missing {
            return
        }
        let currentDate = Date() // Current date and time
        let today = Calendar.autoupdatingCurrent.startOfDay(for: currentDate)
        await MainActor.run {
            if ImageManager.shared.revealNextImage != nil {
                return
            }
            print("Reveal from performBackgroundTask")
            let revealNextImage = RevealNextImage.new(date: today)
            ImageManager.shared.revealNextImage = revealNextImage
        }

        await ImageManager.shared.revealNextImage!.startTrigger()
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

    init() {
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
        guard let wallpaper = ImageManager.shared.currentImage else { return }
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


class RevealNextImage{
    let hideLastImage: Bool
    let at: Date
    let imageUrl: URL?
    let imageDate: Date?
    var triggerStarted: Bool
    var isPictureDownloaded: Bool = false
    var downloadComplete: Bool = false
    var nextTry: Date? = nil
    
    init (revealNextImageAt: Date, url: URL? = nil, date: Date? = nil) {
        self.hideLastImage = true
        self.at = revealNextImageAt
        self.imageUrl = url
        self.imageDate = date
        self.triggerStarted = false
    }

    func removeIfOverdue() async {
        if Date() > self.at {
            print("removed overdue timer")
            await revealImage()
        } else {
            // restart await
            print("restarted trigger")
            self.triggerStarted = true
            await self.startTrigger()
        }
    }
    
    /// to implement
    func downlaodMissingImages() async {
        // only point, where images will be downloaded.
        // use download complete, to signal, that image can be revealed.
        // defer [10,30,60] minutes and check again.
        // write into nextTry, when next downlaod will be tried
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
    
    static func new(date: Date) -> RevealNextImage {
        let interval = calculateTriggerInterval()
        let self_ = RevealNextImage(revealNextImageAt: Date(timeIntervalSinceNow: interval), date: date)
        return self_
    }
    
    // Function to be called when the trigger fires
    func revealImage() async {
        let _ = await ImageManager.shared.downloadMissingImages()
        await MainActor.run {
            print("Image revealed! URL: \(String(describing: imageUrl))")
            ImageManager.shared.revealNextImage = nil
            ImageManager.shared.loadImages()
            ImageManager.shared.showLastImage()
            ImageManager.shared.loadCurrentImage()
        }
    }

    // Async trigger logic using Task.sleep
    func startTrigger() async {
        if triggerStarted {
            return
        }
        triggerStarted = true
        let timeInterval = at.timeIntervalSinceNow
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
        ImageManager.shared.revealNextImage = nil
    }
    
}

// A SwiftUI View for displaying the reveal time
struct RevealNextImageView: View {
    let revealNextImage: RevealNextImage

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
        HStack {
            if isVisible {
                // Semi-transparent text box
                HStack {
                    Text("Reveal next at \(formatToHourMinute(revealNextImage.at))")
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
                                ImageManager.shared.loadImages()
                                ImageManager.shared.showLastImage()
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
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                isVisible = true
            }
        }
    }
}

