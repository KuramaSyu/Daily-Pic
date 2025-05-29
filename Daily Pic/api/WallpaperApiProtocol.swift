//
//  WallpaperApiProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 16.05.25.
//

import Foundation

public protocol WallpaperApiProtocol {
    func downloadImage(of date: Date) async -> WallpaperResponse?
}
