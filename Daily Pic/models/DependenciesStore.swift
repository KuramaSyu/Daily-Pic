//
//  DependenciesStore.swift
//  Daily Pic
//
//  Singleton that exposes the currently-active gallery view model and image
//  tracker to views that live outside the MenuBarExtra scope (e.g. the
//  settings window). Updated from DailyPicApp whenever deps are rebuilt
//  on an api change. Only the menu's currently-rendered api is reachable;
//  callers that need the previous api must read it before the swap.
//

import Foundation
import SwiftUI

@MainActor
public final class DependenciesStore: ObservableObject {
    public static let shared = DependenciesStore()

    /// Currently-active gallery view model. Updated by DailyPicApp when deps rebuild.
    @Published public private(set) var imageManager: (any GalleryViewModelProtocol)?

    /// Currently-active image tracker. Same lifetime as imageManager.
    @Published public private(set) var imageTracker: (any ImageTrackerProtocol)?

    private init() {}

    public func update(
        imageManager: any GalleryViewModelProtocol,
        imageTracker: any ImageTrackerProtocol
    ) {
        self.imageManager = imageManager
        self.imageTracker = imageTracker
    }
}