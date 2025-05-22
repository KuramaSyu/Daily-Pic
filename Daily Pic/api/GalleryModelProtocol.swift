//
//  GalleryModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 14.05.25.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Protocol for settings different save paths
public protocol DataPathProtocol: AnyObject {
    /// name for the specific gallery e.g Bing
    var galleryName: String { get }

    /// Path to the specific gallery, e.g. DailyPic/Bing
    var galleryPath: URL { get }

    /// Path to metadata, usually in galleryPath
    var metadataPath: URL { get }

    // / Path to images, usually in galleryPath
    var imagePath: URL { get }
}

public protocol ImageReloadStrategy {
    func loadPaths(path: URL) -> [URL]?
    func reload<T: NamedImageProtocol>(
        gallery: any GalleryModelProtocol, imageType: T.Type, hiddenDates: Set<Date>?
    ) -> [T]?
    func urlsToImages<T: NamedImageProtocol>(urls: [URL], imageType: T.Type) -> [T]
    func sortImages<T: NamedImageProtocol>(_ images: [T]) -> [T]
    func filterImages<T: NamedImageProtocol>(_ images: [T], hiddenDates: Set<Date>?) -> [T]
}

extension ImageReloadStrategy {
    public func loadPaths(path: URL) -> [URL]? {
        // Retrieve file URLs with their creation date
        let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: path, includingPropertiesForKeys: [.creationDateKey])
        guard let fileURLs else {
            return nil
        }

        // Filter only image files (png, jpg)
        let imageFiles = fileURLs.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "png" || ext == "jpg"
        }
        return imageFiles
    }

    public func urlsToImages<T: NamedImageProtocol>(urls: [URL], imageType: T.Type) -> [T] {
        print("Processing \(urls.count) image URLs")
        
        // Map to an array of NamedImage objects
        return urls.compactMap { fileURL in
            do {
                // Check file existence first
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    print("File doesn't exist: \(fileURL.path)")
                    return nil
                }
                
                // Get resource values with better error handling
                let resourceValues = try fileURL.resourceValues(forKeys: [.typeIdentifierKey, .creationDateKey])
                
                // Check type identifier
                guard let typeIdentifier = resourceValues.typeIdentifier else {
                    print("No type identifier for \(fileURL.lastPathComponent)")
                    return nil
                }
                
                // Check if it's an image using file extension as fallback
                let isImage: Bool
                if let utType = UTType(typeIdentifier), utType.conforms(to: .image) {
                    isImage = true
                } else {
                    // Fallback to extension check
                    let ext = fileURL.pathExtension.lowercased()
                    isImage = ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
                }
                
                guard isImage else {
                    print("Not an image: \(fileURL.lastPathComponent)")
                    return nil
                }
                
                // Get creation date
                guard let creationDate = resourceValues.creationDate else {
                    print("No creation date for \(fileURL.lastPathComponent)")
                    let defaultDate = Date()
                    print("Using current date as fallback")
                    
                    // Create with fallback date
                    return imageType.init(
                        url: fileURL,
                        creation_date: defaultDate,
                        image: nil
                    )
                }
                
                return imageType.init(
                    url: fileURL,
                    creation_date: creationDate,
                    image: nil
                )
            } catch {
                print("Error processing \(fileURL.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    /// filter out iamges, if image has a date in <hiddenDates>
    public func filterImages<T: NamedImageProtocol>(_ images: [T], hiddenDates: Set<Date>?) -> [T] {
        guard let hiddenDates else {
            return images
        }
        let calendar = Calendar.autoupdatingCurrent
        return images.filter {
            !hiddenDates.contains(calendar.startOfDay(for: $0.getDate()!))
        }
    }

    public func reload<T: NamedImageProtocol>(
        gallery: any GalleryModelProtocol, imageType: T.Type, hiddenDates: Set<Date>?
    ) -> [T]? {
        let imageURLs: [URL]? = loadPaths(path: gallery.imagePath)
        guard let imageURLs else {
            print("failed to load images")
            return nil
        }
        let unsortedImages = urlsToImages(urls: imageURLs, imageType: imageType.self)
        let unsortedFilteredImages = filterImages(unsortedImages, hiddenDates: hiddenDates)
        return sortImages(unsortedFilteredImages)
    }
}

/// Strategy to sort images by Date descending
public class ImageReloadByDate: ImageReloadStrategy {
    public func sortImages<T>(_ images: [T]) -> [T] where T: NamedImageProtocol {
        // Sort by creation date
        return images.sorted {
            $0.getDate()! < $1.getDate()!
        }
    }
}

public protocol GalleryModelProtocol: DataPathProtocol {
    associatedtype imageType: NamedImageProtocol
    @Sendable func reloadImages(hiddenDates: Set<Date>)
    func initializeEnvironment()
    var images: [imageType] { get set }
    // Making the reloadStrategy requirement clearer - must be implemented by each model
    var reloadStrategy: any ImageReloadStrategy { get set }
}

extension GalleryModelProtocol {
    public var galleryPath: URL {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        return documentsPath.appendingPathComponent("DailyPic").appendingPathComponent(galleryName)
    }
    public var metadataPath: URL {
        return galleryPath.appendingPathComponent("metadata")
    }
    public var imagePath: URL {
        return galleryPath.appendingPathComponent("images")
    }
    public var iamges: [imageType] {
        get { images }
        set { images = newValue }
    }

    // Remove the recursive reloadStrategy implementation - each model should implement its own

    // Ensure the folder exists (creates it if necessary)
    private func ensureFolderExists(folder: URL) {
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: folder, withIntermediateDirectories: true, attributes: nil)
                print("Folder created at: \(folder.path)")
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }

    public func initializeEnvironment() {
        ensureFolderExists(folder: galleryPath)
        ensureFolderExists(folder: imagePath)
        ensureFolderExists(folder: metadataPath)

    }

    /// Load images from the folder and set them to <images>. Sorting uses the <reloadStrategy>
    @Sendable public func reloadImages(hiddenDates: Set<Date> = []) {
        let images = reloadStrategy.reload(
            gallery: self, imageType: imageType.self, hiddenDates: hiddenDates)
        if images != nil {
            self.images = images!
        }
    }
}
