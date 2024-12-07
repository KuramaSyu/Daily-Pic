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

    }
    
    deinit {
        // Remove observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }
}



class ScreenStateListener {
    private var screenActivationObserver: NSObjectProtocol?
    
    init() {
        setupScreenOnListener()
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
    
    @objc func handleScreenOn() {
        print("Screen turned on at: \(Date()) - Update current picture")
        Task {
            // TODO: 5 min delay
            // TODO: add to imageManager tasks
            // TODO: display in ui
            await performBackgroundTask()

        }
    }
    private func performBackgroundTask() async {
        // Simulate a 5-minute delay
        Swift.print("executing performBackgroundTask")
        var today_is_missing = false
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
        let fiveMinutesLater = currentDate.addingTimeInterval(1 * 60) // 1 * 60 seconds
        await MainActor.run {
            if ImageManager.shared.revealNextImage != nil {
                return
            }
            print("Reveal from performBackgroundTask")
            let revealNextImage = RevealNextImage(revealNextImageAt: fiveMinutesLater, date: today)
            ImageManager.shared.revealNextImage = revealNextImage
        }

        await ImageManager.shared.revealNextImage!.startTrigger()
    }
    
    deinit {
        if let observer = screenActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
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
            // TODO: Add relevant logic for workspace change handling
            // TODO: 5 min delay
            // TODO: Add to imageManager tasks
            // TODO: Display in UI
            guard let wallpaper = ImageManager.shared.currentImage else { return }
            print("\(wallpaper)")
            WallpaperHandler().setWallpaper(image: wallpaper.url)
        
        // Add your custom logic here
    }
    
    deinit {
        if let observer = workspaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}



class RevealNextImage{
    let hideLastImage: Bool
    let at: Date
    let imageUrl: URL?
    let imageDate: Date?
    var triggerStarted: Bool
    
    init (revealNextImageAt: Date, url: URL? = nil, date: Date? = nil) {
        self.hideLastImage = true
        self.at = revealNextImageAt
        self.imageUrl = url
        self.imageDate = date
        self.triggerStarted = false
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
                VStack {
                    Text("Reveal next at \(formatToHourMinute(revealNextImage.at))")
                        .font(.footnote)
                }
                .padding(.vertical, 6)  // padding from last toggle to bottom
                .padding(.horizontal, 10)  // padding at left for >
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .contentShape(Rectangle()) // Makes the entire label tappable
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale)) // Apply animation
                .animation(.easeInOut(duration: 0.3), value: isVisible)
            }
        }
        .onAppear {
            // Trigger visibility when the view appears
            withAnimation {
                isVisible = true
            }
        }
    }
}

