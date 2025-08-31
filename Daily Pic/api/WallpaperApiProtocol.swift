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
    func fetchResponse(of date: Date) async -> WallpaperResponse?
}
