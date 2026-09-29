//
//  ImageMetadata.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.09.26.
//

import Foundation
import ImageIO

/// Read the original creation date from an image's EXIF metadata.
enum ImageMetadata {
    /// Returns DateTimeOriginal, then DateTimeDigitized, then TIFF DateTime.
    /// Nil if the file has no usable date field.
    static func creationDate(for url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            for key in [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifDateTimeDigitized] {
                if let raw = exif[key] as? String, let date = exifDateFormatter.date(from: raw) {
                    return date
                }
            }
        }
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = exifDateFormatter.date(from: raw) {
            return date
        }
        return nil
    }

    // EXIF DateTime fields are local time; no timezone applied (season buckets ignore it).
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
