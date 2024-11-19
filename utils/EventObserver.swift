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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is called when the app is first launched
        screenListener = ScreenStateListener()
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
        print("Screen turned on at: \(Date())")
        // Add your custom logic here
    }
    
    deinit {
        if let observer = screenActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
