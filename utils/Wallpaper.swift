//
//  Wallpaper.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//

import Foundation
import SwiftUI

/// Applies an image as the desktop wallpaper of every attached screen.
///
/// `NSScreen` and `NSWorkspace` are AppKit types and are not safe to use
/// from a background thread, so the work is pinned to the main actor. The
/// previous implementation ran it inside a task-group child — i.e. on a
/// background thread — and wrapped it in a `race()` that was supposed to
/// cap the wait at 0.3 s. That cap never applied: `withThrowingTaskGroup`
/// waits for *all* children before returning, so a slow apply still blocked
/// the caller for its full duration. The apply is fast (a window-server
/// round trip, ~10 ms), so the timeout is simply dropped rather than
/// reimplemented on top of a primitive that cannot express it.
@MainActor
final class WallpaperHandler {
    /// Sets `image` as the desktop picture of every attached screen.
    ///
    /// Screens already showing `image` are skipped, so re-applying the
    /// current wallpaper does not churn the window server.
    func setWallpaper(image: URL) async {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            RuntimeLog.write("wallpaper: no screens attached")
            return
        }
        for screen in screens {
            guard NSWorkspace.shared.desktopImageURL(for: screen) != image else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: [:])
            } catch {
                // Logged rather than printed: a failed wallpaper set is
                // invisible in the popover but is exactly the kind of event
                // the runtime log exists to capture.
                RuntimeLog.write("wallpaper: set failed for \(screen.localizedName): \(error.localizedDescription)")
            }
        }
    }
}
