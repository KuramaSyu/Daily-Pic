//
//  WallpaperAdapterProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//
import Foundation

public protocol WallpaperMarket {
    var images: [WallpaperProtocol] {get set}
}

/// represents the protocol for classes which represent one specific
/// wallpaper from one specific market
public protocol WallpaperProtocol {
    func saveFile() async throws
    func getImageURL() -> URL
    func getImageName() -> String
    func getJsonName() -> String
}


public protocol WallpaperResponse {
    var images: [WallpaperProtocol] {get set}
}
