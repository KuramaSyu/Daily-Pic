import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private init() {
        // Create the settings view
        let settingsView = SettingsView()
        
        // Create the hosting controller
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        
        // Prevent the window from showing in the dock
        window.level = .floating
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showSettings() {
        guard let window = window else { return }
        
        // If window is already visible, just bring it to front
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Center the window on screen
        window.center()
    }
    
    func hideSettings() {
        window?.orderOut(nil)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Configure window behavior
        window?.delegate = self
    }
}

// MARK: - NSWindowDelegate
extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Optional: Perform any cleanup when window closes
        // You can save settings here if needed
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of closing to keep the window instance alive
        hideSettings()
        return false
    }
}
