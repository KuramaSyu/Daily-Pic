//
//  NamedOsuImage.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.08.25.
//

//
//  NamedBingImage.swift
//  Daily Pic
//
//  Created by Paul Zenker on 19.05.25.
//

import SwiftUI
import AppKit
import ImageIO


public class NamedOsuImage: NamedImageProtocol  {
    // Dropdown copyright line: "Artist - Spring 2026" / "Shirane - Spring 2026".
    // Falls back to just the username if season is missing (legacy files)
    // and to a static string if even the username is missing (very old
    // files with no metadata JSON).
    public func getCopyrightDescription() -> String? {
        if metadata == nil { getMetaData() }
        let username = metadata?.user.username ?? metadata?.displayName ?? "osu! community"
        let country = metadata?.user.country_code ?? ""
        let suffix = country.isEmpty ? username : "\(username) (\(country))"
        guard let season = metadata?.season,
              let year = metadata?.year else {
            return suffix
        }
        return "\(suffix) - \(season) \(year)"
    }

    public var url: URL
    // Menu title = the artist's osu! username. Falls back to the hash
    // filename for legacy images whose metadata has no displayName.
    public func getTitle() -> String {
        if metadata == nil { getMetaData() }
        if let name = metadata?.displayName, !name.isEmpty { return name }
        if let name = metadata?.user.username, !name.isEmpty { return name }
        return url.lastPathComponent
    }

    let creation_date: Date
    var metadata: OsuWallpaperResponse?
    var image: NSImage?
    /// Tracks the most recent access so an idle cached NSImage can be freed.
    private var lastLoadedAt: Date?

    required public init(url: URL, creation_date: Date, image: NSImage? = nil) {
        self.creation_date = creation_date
        self.url = url
    }

    deinit {
        image = nil
    }

    public func exists() -> Bool {
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
    /// get metadata form metadata/YYYYMMDD_name.json
    /// and store it in .metadata. Can fail
    /// needs the
    func getMetaData() {
        // strip _UHD.jpeg from image
        let metadata_dir = OsuGalleryModel(loadImages: false).metadataPath
        if metadata != nil { return }
        let image_name = String(url.lastPathComponent.removingPercentEncoding!.split(separator: ".jpg").first!)
        let metadata_path = metadata_dir.appendingPathComponent("\(image_name).json")
        let metadata = try? JSONDecoder().decode(OsuWallpaperResponse.self, from: Data(contentsOf: metadata_path))
        if let metadata = metadata {
            self.metadata = metadata
        } else {
            print("failed to load metadata from \(metadata_path)")
        }
    }
    
    // Implement the required `==` operator for equality comparison
    public static func ==(lhs: NamedOsuImage, rhs: NamedOsuImage) -> Bool {
        return lhs.url.lastPathComponent == rhs.url.lastPathComponent
    }

    // Implement the required `hash(into:)` method
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url.lastPathComponent)
    }
    
    // Implement the description property for custom printing
    public func getDescription() -> String {
        return "NamedImage(url: \(url))"
    }
    
    public func getSubtitle() -> String {
        let wrap_text = { (date: String) in return "One Picture from \(date)" }

        return wrap_text(DateParser.prettyDate(for: self.getDate()!))
    }
    
    /// - returns:
    /// a DateFormat for yyyyMMdd
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    /// - returns:
    /// the creation date of the image by JSON Bing Metadata or by actuall creation date
    public func getDate() -> Date? {
        let string: String = String(url.lastPathComponent)
        var parsedDate: Date = creation_date
        if let extracted_date = _stringToDate(from: string) {
            parsedDate = extracted_date
        }
        return parsedDate
    }
    
    /// - returns:
    ///  the scaled down Image (scaled down to lower RAM footprint)
    public func loadNSImage() -> NSImage? {
        if let cached = image { return cached }
        let scale_factor = CGFloat(0.2)
        let loaded = ImageLoader(url: self.url, scale_factor: scale_factor).getImage()
        image = loaded
        lastLoadedAt = Date()
        return loaded
    }



    public func unloadImage() {
        self.image = nil
        self.lastLoadedAt = nil
    }

    /// Drop the cached bitmap if it has been idle longer than <ttl> seconds.
    @discardableResult
    public func evictIfIdle(ttl: TimeInterval = 30) -> Bool {
        guard image != nil, let loadedAt = lastLoadedAt else { return false }
        if Date().timeIntervalSince(loadedAt) >= ttl {
            image = nil
            lastLoadedAt = nil
            return true
        }
        return false
    }
    /// loads image without RAM footprint
    func loadCGImage() -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    /// Format the date to "24th November" format
    func prettyDate(from date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(DateParser.ordinalSuffix(for: date))' MMMM"
        return outputFormatter.string(from: date)
    }
    
    /// converts a string containing yyyyMMdd to a Date object
    func _stringToDate(from string: String) -> Date? {
        let dateFormatter = DateParser.dateFormatter
        guard let regex = DateParser.regex else { return nil }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        if let match = regex.firstMatch(in: string, options: [], range: range),
           let matchRange = Range(match.range, in: string) {
            let datePart = String(string[matchRange])
            return dateFormatter.date(from: datePart)
        }
        return nil
    }
}
