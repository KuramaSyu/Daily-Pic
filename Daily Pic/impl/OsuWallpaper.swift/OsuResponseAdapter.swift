//
//  OsuResponseAdapter.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

/// Converts Response (Bing Specific) to a WallpaperResponse
class OsuWallpaperAdapter: WallpaperResponse {
    var images: [any WallpaperProtocol]
    init(_ response: OsuSeasonalBackgroundsResponse) {
        images = []
        for background in response.backgrounds {
            images.append(
                OsuWallpaper(metadata: background)
            )
        }
    }
}
