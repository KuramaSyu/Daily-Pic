//
//  GalleryModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 14.05.25.
//

import Foundation

public protocol GalleryModelProtocol {
    var folderUrl: URL { get }
    var metadataPath: URL { get }
    @Sendable func reloadImages(hiddenDates: Set<Date>)
    var images: [NamedImage] { get }
}
