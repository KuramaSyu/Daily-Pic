//
//  GalleryModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 14.05.25.
//

import Foundation
import UniformTypeIdentifiers

public protocol GalleryModelProtocol {
    var galleryName: String { get }
    var galleryPath: URL { get }
    var metadataPath: URL { get }
    var imagePath: URL { get }
    @Sendable mutating func reloadImages(hiddenDates: Set<Date>)
    func initializeEnvironment()
    var images: [NamedImage] { get set }
    
}

public extension GalleryModelProtocol {
    var galleryPath: URL {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("DailyPic")
    }
    var metadataPath: URL {
        return galleryPath.appendingPathComponent("metadata")
    }
    var imagePath: URL {
        return galleryPath.appendingPathComponent("images")
    }
    var iamges: [NamedImage] {
        get { images }
        set { images = newValue }
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
    
    func initializeEnvironment() {
        ensureFolderExists(folder: galleryPath)
        ensureFolderExists(folder: imagePath)
        ensureFolderExists(folder: metadataPath)

    }
    
    /// Load images from the folder
    @Sendable mutating func reloadImages(hiddenDates: Set<Date> = []) {
        do {
            // Retrieve file URLs with their creation date
            let fileURLs = try FileManager.default.contentsOfDirectory(at: galleryPath, includingPropertiesForKeys: [.creationDateKey])
            
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
}
