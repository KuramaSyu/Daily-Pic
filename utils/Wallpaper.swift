//
//  Wallpaper.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//

import Foundation
import SwiftUI

class WallpaperHandler {
    func _setWallpaper(image: URL) {
        do {
            let screens = NSScreen.screens
            for i in screens {
                guard NSWorkspace.shared.desktopImageURL(for: i) != image else {
                    continue
                }
                try NSWorkspace.shared.setDesktopImageURL(image, for: i, options: [:])
            }
        } catch {
            print(error)
        }
    }
    
    func setWallpaper(image: URL) async {
        _ = try? await race(
            {
                self._setWallpaper(image: image)
                throw TimeoutError.timeout
            },
            {
                try await Task.sleep(nanoseconds: UInt64( (0.3 * 1e9)))
            }
        )
    }
}
