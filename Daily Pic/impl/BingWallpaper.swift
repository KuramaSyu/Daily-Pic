//
//  BingWallpaperAdapter.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//
import Foundation

class BingWallpaper: WallpaperAdapterProtocol {
    let metadata: BingImage
    let gallery: any GalleryModelProtocol = BingGalleryModel();
    init(metadata: BingImage) {
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
        URL(string: "https://bing.com\(metadata.urlbase)_UHD.jpg")!
    }
    
    func getImageName() -> String {
        "\(_makeFileName())_UHD.jpg"
    }
    
    func getJsonName() -> String {
        "\(_makeFileName()).json"
    }
    
    func _makeFileName() -> String {
        let id = metadata.urlbase.replacing("/th?id=OHR.", with: "", maxReplacements: 1)
        return "\(metadata.enddate)_\(id)"
    }
    
    
}
