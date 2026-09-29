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

    // All optional so pre-feature JSON decodes cleanly. Stamped at save time.
    var displayName: String?
    var season: String?
    var year: Int?
    var metaSchemaVersion: Int?

    // Bump when backfill rules change. v3 = EXIF DateTimeOriginal with mtime fallback.
    static let currentMetaSchemaVersion = 3
}

struct OsuUser: Codable {
    let avatar_url: String
    let country_code: String
    let id: Int
    //let is_active: Bool
    let username: String
}

// One of the four seasons osu! rotates through on its ~90-day cadence.
// Used only for the dropdown copyright line -- the menu title is the
// artist's username. Kept as a plain String in JSON so we can add more
// granular seasons later without breaking older files.
enum OsuSeasonLabel: String, CaseIterable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"

    // Meteorological season for a given date. Winter straddles the year
    // boundary (Dec-Feb); the returned year is the year that contains
    // the Jan/Feb end so "Winter 2025" spans Dec 2025 - Feb 2026.
    static func label(for date: Date, calendar: Calendar = .current) -> (label: OsuSeasonLabel, year: Int)? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let m = comps.month, let y = comps.year else { return nil }
        switch m {
        case 3...5: return (.spring, y)
        case 6...8: return (.summer, y)
        case 9...11: return (.fall, y)
        default:
            return (.winter, m == 12 ? y : y - 1)
        }
    }
}


// one record
struct FetchedRecord: Hashable, Codable {
    let date: Date
    let sha256: String
}

/// used for hashing a struct of osu seasonal backgrounds. This only uses
/// the image urls, since user names, localtions and if they are online is unimportant
/// to the hash
public struct FilteredOsuSeasonalBackgroundsResponse: Codable {
    let backgrounds: [String]
}




