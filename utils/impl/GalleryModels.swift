//
//  GalleryModels.swift
//  Daily Pic
//
//  Created by Paul Zenker on 15.05.25.
//
import SwiftUI
import os
import UniformTypeIdentifiers

class BingGalleryModel: GalleryModelProtocol {
    static let shared = BingGalleryModel()
    var images: [NamedImage] = [];
    public let folderPath: URL
    public let metadataPath: URL
    var config: Config? = nil
    
    var galleryName: String { "Bing" }

    init() {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        folderPath = documentsPath.appendingPathComponent("DailyPic")
        metadataPath = folderPath.appendingPathComponent("metadata")
        initialsizeEnvironment()
        reloadImages()
    }

    // Ensure the folder exists (creates it if necessary)
    private func ensureFolderExists(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(folder.path)")
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }
    
    private func initialsizeEnvironment() {
        ensureFolderExists(folder: folderPath)
        ensureFolderExists(folder: metadataPath)
    }
    
    /// Load images from the folder
    @Sendable func reloadImages(hiddenDates: Set<Date> = []) {
        do {
            // Retrieve file URLs with their creation date
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderPath, includingPropertiesForKeys: [.creationDateKey])
            
            // Filter only image files (png, jpg)
            let imageFiles = fileURLs.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "png" || ext == "jpg"
            }
            

            
            // Map to an array of NamedImage objects
            var unsorted_images: [NamedImage] = imageFiles.compactMap { fileURL in
                // Check if the file is a valid image without allocating memory for NSImage
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]),
                      let typeIdentifier = resourceValues.typeIdentifier,
                      UTType(typeIdentifier)?.conforms(to: .image) == true,
                      let creationDate = (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate else {
                    return nil
                }

                return NamedImage(
                    url: fileURL,
                    creation_date: creationDate,
                    image: nil  // only load when needed
                )
            }
            
            // hide images which are hidden
            let calendar = Calendar.autoupdatingCurrent
            unsorted_images = unsorted_images.filter {
                !hiddenDates.contains(calendar.startOfDay(for: $0.getDate()))
            }

            // Sort by creation date
            images = unsorted_images.sorted {
                $0.getDate() < $1.getDate()
            }
            print("\(images.count) images loaded.")
        } catch {
            print("Failed to load images: \(error)")
        }
    }
    
    /// ensures that path exists else init it with default_value
    func ensureFileExists(path: URL, default_value: Codable) {
        guard !FileManager.default.fileExists(atPath: path.path) else { return }
        // Encode the Config instance to Data
        let encoder = JSONEncoder()
        if let configData = try? encoder.encode(default_value) {
            // Create the file with the encoded data
            FileManager.default.createFile(
                atPath: path.path,
                contents: configData,
                attributes: nil
            )
        } else {
            // Handle error if encoding fails
            print("Failed to encode path: \(path)")
        }
    }

}
