//
//  OsuWallpaper.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

import Foundation

class OsuWallpaper: WallpaperProtocol {
    let metadata: OsuWallpaperResponse
    let gallery: any GalleryModelProtocol = OsuGalleryModel();
    init(metadata: OsuWallpaperResponse) {
        self.metadata = metadata
    }
    func saveFile() async throws {
        // Move the file operations to a background task
        try await Task.detached(priority: .userInitiated) {
            let dir = self.gallery.metadataPath.appendingPathComponent(self.getJsonName())
            
            // setup JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // encode metadata
            let data = try encoder.encode(self.metadata)
            try data.write(to: dir)
        }.value
    }
    
    func getImageURL() -> URL {
        URL(string: self.metadata.url)!
    }
    
    func getImageName() -> String {
        "\(_makeFileName()).jpg"
    }
    
    func getJsonName() -> String {
        "\(_makeFileName()).json"
    }
    
    /// use only the base64 part of the url as name
    func _makeFileName() -> String {
        let hash = metadata.url.replacing("https://assets.ppy.sh/user-contest-entries/", with:"").replacing(".jpg", with: "")
        return String(hash.split(separator: "/").last ?? "")
    }
}
