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
    var filtered_response: FilteredOsuSeasonalBackgroundsResponse
    init(_ response: OsuSeasonalBackgroundsResponse, gallery_model: any GalleryModelProtocol) {
        images = []
        self.response = response
        var urls: [String] = []
        for background in response.backgrounds {
            urls.append(background.url)
            images.append(
                OsuWallpaper(metadata: background, gallery_model: gallery_model)
            )
        }
        self.filtered_response = FilteredOsuSeasonalBackgroundsResponse(backgrounds: urls)
    }
}
