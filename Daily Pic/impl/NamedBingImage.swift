//
//  NamedBingImage.swift
//  Daily Pic
//
//  Created by Paul Zenker on 19.05.25.
//

import SwiftUI
import AppKit
import ImageIO


public class NamedBingImage: NamedImageProtocol  {
    
    public func getTitle() -> String {
        self.metadata?.title ?? url.lastPathComponent
    }
    
    let url: URL
    let creation_date: Date
    var metadata: BingImage?
    var image: NSImage?
    
    init(url: URL, creation_date: Date, image: NSImage? = nil) {
        self.url = url
        self.creation_date = creation_date
    }

    public func exists() -> Bool {
        print("check path: \(url.path(percentEncoded: false))")
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
    /// get metadata form metadata/YYYYMMDD_name.json
    /// and store it in .metadata. Can fail
    /// needs the
    func getMetaData() {
        // strip _UHD.jpeg from image
        let metadata_dir = BingGalleryModel.shared.metadataPath
        if metadata != nil { return }
        let image_name = String(url.lastPathComponent.removingPercentEncoding!.split(separator: "_UHD").first!)
        let metadata_path = metadata_dir.appendingPathComponent("\(image_name).json")
        let metadata = try? JSONDecoder().decode(BingImage.self, from: Data(contentsOf: metadata_path))
        if let metadata = metadata {
            self.metadata = metadata
            print("loaded Metadata for \(metadata.title)")
        } else {
            print("failed to load metadata from \(metadata_path)")
        }
    }
    
    // Implement the required `==` operator for equality comparison
    public static func ==(lhs: NamedBingImage, rhs: NamedBingImage) -> Bool {
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
        let wrap_text = { (date: String) in return "Picture of \(date)" }

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
        let string: String = metadata?.enddate ?? String(url.lastPathComponent)
        var parsedDate: Date = creation_date
        if let extracted_date = _stringToDate(from: string) {
            parsedDate = extracted_date
        }
        return parsedDate
    }
    
    /// - returns:
    ///  the scaled down Image (scaled down to lower RAM footprint)
    func loadNSImage() -> NSImage? {
        let scale_factor = CGFloat(0.2)
        return ImageLoader(url: self.url, scale_factor: scale_factor).getImage()
    }
    
    
    public func unloadImage() {
        self.image = nil
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
