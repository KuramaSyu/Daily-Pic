//
//  JsonType.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//
import Foundation
import CryptoKit

struct OsuSeasonalBackgroundsResponse: Codable {
    let backgrounds: [OsuWallpaperResponse]
}
struct OsuWallpaperResponse: Codable {
    let url: String
    let user: OsuUser
}

struct OsuUser: Codable {
    let avatar_url: String
    let country_code: String
    let id: Int
    let is_active: Bool
    let username: String
}


// one record
struct FetchedRecord: Hashable, Codable {
    let data: Date
    let sha256: String
}





