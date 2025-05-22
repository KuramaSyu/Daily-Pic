//
//  GalleryModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 14.05.25.
//

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
    @Sendable func reload<T: NamedImageProtocol>(gallery: any GalleryModelProtocol, imageType: T.Type, hiddenDates: Set<Date>?) -> [T]?
    func urlsToImages<T: NamedImageProtocol>(urls: [URL], imageType: T.Type) -> [T]
    func sortImages<T: NamedImageProtocol>(_ images: [T]) -> [T]
    func filterImages<T: NamedImageProtocol>(_ images: [T], hiddenDates: Set<Date>?) -> [T]
}


public extension ImageReloadStrategy {
    func loadPaths(path: URL) -> [URL]? {
        // Retrieve file URLs with their creation date
        let fileURLs = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.creationDateKey])
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
    
    func urlsToImages<T: NamedImageProtocol>(urls: [URL], imageType: T.Type) -> [T] {
        // Map to an array of NamedImage objects
        return urls.compactMap { fileURL in
            // Check if the file is a valid image without allocating memory for NSImage
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]),
                  let typeIdentifier = resourceValues.typeIdentifier,
                  UTType(typeIdentifier)?.conforms(to: .image) == true,
                  let creationDate = (try? fileURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate else {
                return nil
            }

            return imageType.init(
                url: fileURL,
                creation_date: creationDate,
                image: nil  // only load when needed
            )
        }
    }
    
    /// filter out iamges, if image has a date in <hiddenDates>
    func filterImages<T: NamedImageProtocol>(_ images: [T], hiddenDates: Set<Date>?) -> [T] {
        guard let hiddenDates else {
            return images
        }
        let calendar = Calendar.autoupdatingCurrent
        return images.filter {
            !hiddenDates.contains(calendar.startOfDay(for: $0.getDate()!))
        }
    }
    
    @Sendable func reload<T: NamedImageProtocol>(gallery: any GalleryModelProtocol, imageType: T.Type, hiddenDates: Set<Date>?) -> [T]? {
        let imageURLs: [URL]? = loadPaths(path: gallery.imagePath);
        guard let imageURLs else {
            return nil
        }
        let unsortedImages = urlsToImages(urls: imageURLs, imageType: imageType.self);
        let unsortedFilteredImages = filterImages(unsortedImages, hiddenDates: hiddenDates)
        return sortImages(unsortedFilteredImages);
    }
}

/// Strategy to sort images by Date descending
public class ImageReloadByDate: ImageReloadStrategy {
    public func sortImages<T>(_ images: [T]) -> [T] where T : NamedImageProtocol {
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
    var reloadStrategy: any ImageReloadStrategy { get set }
}

public extension GalleryModelProtocol {
    var galleryPath: URL {
        // Path to ~/Documents/DailyPic/
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("DailyPic").appendingPathComponent(galleryName)
    }
    var metadataPath: URL {
        return galleryPath.appendingPathComponent("metadata")
    }
    var imagePath: URL {
        return galleryPath.appendingPathComponent("images")
    }
    var iamges: [imageType] {
        get { images }
        set { images = newValue }
    }
    
    var reloadStrategy: any ImageReloadStrategy {
        get { reloadStrategy }
        set { reloadStrategy = newValue }
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
    
    /// Load images from the folder and set them to <images>. Sorting uses the <reloadStrategy>
    @Sendable func reloadImages(hiddenDates: Set<Date> = []) {
        let images = reloadStrategy.reload(gallery: self, imageType: imageType.self, hiddenDates: hiddenDates);
        if images != nil {
            self.images = images!
        }
    }
}
