//
//  WallpaperAutoApplyStore.swift
//  Daily Pic
//
//  Mirror of Config.toggles.set_wallpaper_on_navigation as an ObservableObject
//  so SwiftUI views outside the DropdownWithToggles scope (QuickActions)
//  re-render when the user flips auto-apply on or off. The on-disk config
//  remains the source of truth -- this store is just a reactive view onto it.
//

import Foundation
import SwiftUI

@MainActor
public final class WallpaperAutoApplyStore: ObservableObject {
    public static let shared = WallpaperAutoApplyStore()

    @Published public var enabled: Bool = false

    private init() {}

    /// Seed from the gallery VM's config so the menu and settings agree on
    /// the current state at launch.
    public func seed(from config: Config) {
        enabled = config.toggles.set_wallpaper_on_navigation
    }
}