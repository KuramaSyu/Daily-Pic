//
//  OsuWallpaperGallery.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.08.25.
//

import SwiftUI
import UniformTypeIdentifiers
import os

class OsuGalleryModel: GalleryModelProtocol {
    var images: [NamedOsuImage] = []
    var config: Config? = nil
    var reloadStrategy: any ImageReloadStrategy

    var galleryName: String { "osu" }

    init(loadImages: Bool = true) {
        self.reloadStrategy = ImageReloadByDate()
        if loadImages {
            initializeEnvironment()
            // Stamp season/year into legacy metadata files; no-op once schemaVersion is current.
            OsuSeasonBackfill.run(in: metadataPath)
        }

    }
}

// Stamps season/year into each osu! {hash}.json. Prefers EXIF DateTimeOriginal; falls back to JSON mtime; finally today.
enum OsuSeasonBackfill {
    static func run(in metadataPath: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: metadataPath,
            includingPropertiesForKeys: nil
        ) else { return }
        let jsonFiles = entries.filter { $0.pathExtension == "json" }
        guard !jsonFiles.isEmpty else { return }

        let currentVersion = OsuWallpaperResponse.currentMetaSchemaVersion
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        // .../osu/metadata -> .../osu/images
        let imagePath = metadataPath
            .deletingLastPathComponent()
            .appendingPathComponent("images")

        var didWrite = false
        for url in jsonFiles {
            guard let data = try? Data(contentsOf: url),
                  let meta = try? JSONDecoder().decode(OsuWallpaperResponse.self, from: data) else {
                continue
            }
            // Skip already-stamped files.
            if meta.metaSchemaVersion == currentVersion { continue }

            // EXIF preferred; legacy re-encoded jpegs have no EXIF and fall through to mtime.
            let jpgURL = imagePath.appendingPathComponent(
                url.deletingPathExtension().lastPathComponent + ".jpg"
            )
            let exif = ImageMetadata.creationDate(for: jpgURL)
            let mtime = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            let source = exif ?? mtime
            let resolved = source.flatMap { OsuSeasonLabel.label(for: $0) }

            var updated = meta
            if let resolved = resolved {
                updated.season = resolved.label.rawValue
                updated.year = resolved.year
            } else if updated.season == nil || updated.year == nil {
                // Last resort: stamp today so the dropdown has *something*.
                if let now = OsuSeasonLabel.label(for: Date()) {
                    if updated.season == nil { updated.season = now.label.rawValue }
                    if updated.year == nil { updated.year = now.year }
                }
            }
            updated.metaSchemaVersion = currentVersion

            if let data = try? encoder.encode(updated) {
                try? data.write(to: url, options: .atomic)
                didWrite = true
            }
        }

        if didWrite {
            RuntimeLog.write("osu! season backfill: re-stamped legacy files")
        }
    }
}

