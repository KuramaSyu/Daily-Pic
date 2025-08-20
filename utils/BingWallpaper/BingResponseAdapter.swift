//
//  BingResponseAdapter.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

/// Converts Response (Bing Specific) to a WallpaperResponse
class BingResponseAdapter: WallpaperResponse {
    var images: [any WallpaperProtocol]
    init(_ response: BingApiResponse) {
        images = []
        for image in response.images {
            images.append(BingWallpaper(metadata: image))
        }
    }
}
