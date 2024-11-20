//
//  JsonType.swift
//  DailyPic
//
//  Created by Paul Zenker on 20.11.24.
//

import Foundation

// MARK: - Root struct
struct Response: Codable {
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
    
    func saveFile(to_dir url: URL) throws {
        let dir = url.appendingPathComponent(makeFileName())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: dir)
    }
    
    func makeFileName() -> String {
        "\(startdate)_\(title).json"
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
