//
//  JsonType.swift
//  Daily Pic
//
//  Created by Paul Zenker on 20.08.25.
//

struct SeasonalBackgroundsResponse: Codable {
    let backgrounds: [OsuWallpaper]
}
struct OsuWallpaper: Codable {
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
