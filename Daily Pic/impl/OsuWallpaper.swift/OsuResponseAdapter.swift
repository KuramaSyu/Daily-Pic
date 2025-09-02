//
//  OsuResponseAdapter.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

/// Converts Response (Bing Specific) to a WallpaperResponse
class OsuWallpaperAdapter: WallpaperResponse {
    var images: [any WallpaperProtocol]
    var response: OsuSeasonalBackgroundsResponse
    
    init(_ response: OsuSeasonalBackgroundsResponse, gallery_model: any GalleryModelProtocol) {
        images = []
        Swift.print("1.1.1")
        self.response = response
        for background in response.backgrounds {
            Swift.print("1.1.2")
            images.append(
                OsuWallpaper(metadata: background, gallery_model: gallery_model)
            )
        }
    }
}
