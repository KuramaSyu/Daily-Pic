//
//  WallpaperApiProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 16.05.25.
//

import Foundation

public protocol WallpaperApiProtocol {
    /// Fetches the JSON Response from the API, which implements this protocol
    ///
    /// # Returns:
    /// * WallpaperResponse - the response packed into an Interface
    func fetchResponse(of date: Date) async throws -> WallpaperResponse?
}

/// Optional user-visible log surfaced in the info popover.
/// Each conforming type decides whether to store it; see `OsuWallpaperApi`.
public protocol InfoLogging {
    var infoLog: InfoLog? { get set }
}
