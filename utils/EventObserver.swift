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
        Swift.print("Waiting for 5 minutes before executing task...")
        var date_is_missing = false
        ImageManager.shared.loadImages()
        let dates = ImageManager.shared.getMissingDates()
        let cal = Calendar.autoupdatingCurrent
            for date in dates {
                if cal.isDateInToday(date) {
                    date_is_missing = true
                }
            }
        
        if !date_is_missing {
            return
        }
        Swift.print("sleep start")
        try? await Task.sleep(nanoseconds: 5 * 10 * 1_000_000_000)
        Swift.print("sleep over")
        // Perform the task
        //print("Executing delayed task at: \(Date())")
        let current_image_url = ImageManager.shared.currentImageUrl
        let _ = await ImageManager.shared.downloadMissingImages()
        await MainActor.run {
            
            ImageManager.shared.loadImages()
            ImageManager.shared.showLastImage()
            // ImageManager.shared.setIndexByUrl(url)
        }
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
