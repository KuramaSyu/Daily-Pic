//
//  OsuWallpaper.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

import Foundation

class OsuWallpaper: WallpaperProtocol {
    var metadata: OsuWallpaperResponse
    let gallery: any GalleryModelProtocol;

    init(metadata: OsuWallpaperResponse, gallery_model: any GalleryModelProtocol) {
        self.metadata = metadata
        self.gallery = gallery_model
    }
    func saveFile() async throws {
        // File ops on a background task.
        try await Task.detached(priority: .userInitiated) {
            // Snapshot so we don't mutate the shared response.
            var snapshot = self.metadata
            if snapshot.displayName == nil {
                snapshot.displayName = snapshot.user.username
            }
            if snapshot.season == nil || snapshot.year == nil {
                // Read EXIF from the saved jpg (imagePath is populated by the time we get here).
                let source = ImageMetadata.creationDate(for: self.gallery.imagePath.appendingPathComponent(self.getImageName()))
                    ?? Date()
                if let resolved = OsuSeasonLabel.label(for: source) {
                    if snapshot.season == nil { snapshot.season = resolved.label.rawValue }
                    if snapshot.year == nil { snapshot.year = resolved.year }
                }
            }
            snapshot.metaSchemaVersion = OsuWallpaperResponse.currentMetaSchemaVersion
            let dir = self.gallery.metadataPath.appendingPathComponent(self.getJsonName())

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snapshot)
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
