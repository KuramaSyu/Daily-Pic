//
//  config.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//
import SwiftUI


struct ConfigToggles: Codable {
    var autostart: Bool
    var shuffle_favorites_only: Bool
    var set_wallpaper_on_navigation: Bool
}

struct Config: Codable {
    var favorites: Set<String>
    var languages: [String]  // index 0 for first Workspace, 1 for 2nd, 2 for 3rd ...
    var toggles: ConfigToggles
    var current_index: Int
    var wallpaper_url: String?
    
    
    static func load(from url: URL) -> Config? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        do {
            let config = try decoder.decode(Config.self, from: data)
            print("loaded Config")
            return config
        } catch {
            print("Failed to load Config")
            return nil
        }
    }
    
    
    func write(to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return }

        // Ensure the directory exists, create it if not
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory: \(error)")
                return
            }
        }
        
        // Write or override
        do {
            try data.write(to: url)
            print("Config written successfully to \(url.path)")
        } catch {
            print("Failed to write config to file: \(error)")
        }
    }
    
    
    static func getDefault() -> Config {
        return Config(
            favorites: [],
            languages: [],
            toggles: ConfigToggles(
                autostart: false,
                shuffle_favorites_only: false,
                set_wallpaper_on_navigation: true
            ),
            current_index: -1,
            wallpaper_url: nil
        )
    }
 }
