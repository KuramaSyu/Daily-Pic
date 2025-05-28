//
//  JsonType.swift
//  DailyPic
//
//  Created by Paul Zenker on 20.11.24.
//

import Foundation

// MARK: - Root struct
public struct Response: Codable {
    let market: Market
    let images: [BingImage]
}

// MARK: - Market struct
struct Market: Codable {
    let mkt: String
}

// MARK: - Image struct
struct BingImage: Codable {
    let startdate: String
    let fullstartdate: String
    let enddate: String
    let url: String
    let urlbase: String
    let copyright: String
    let copyrightlink: String
    let title: String
    let drk: Int
    
    func saveFile(to_dir url: URL) async throws {
        // Move the file operations to a background task
        try await Task.detached(priority: .userInitiated) {
            let dir = url.appendingPathComponent(self.getJsonName())
            
            // setup JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // encode self
            let data = try encoder.encode(self)
            try data.write(to: dir)
        }.value
    }
    
    func _makeFileName() -> String {
        let id = urlbase.replacing("/th?id=OHR.", with: "", maxReplacements: 1)
        return "\(enddate)_\(id)"
    }
    func getJsonName() -> String {
        "\(_makeFileName()).json"
    }
    
    func getImageName() -> String {
        "\(_makeFileName())_UHD.jpg"
    }
    
    func getImageURL() -> URL {
        URL(string: "https://bing.com\(urlbase)_UHD.jpg")!
    }
}

// MARK: - Tooltips struct
struct Tooltips: Codable {
    let loading: String
    let previaous: String
    let next: String
    let walle: String
    let walls: String
}
