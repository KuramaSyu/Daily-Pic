import AppKit
import Foundation
//
//  GalleryModels.swift
//  Daily Pic
//
//  Created by Paul Zenker on 15.05.25.
//
import SwiftUI
import UniformTypeIdentifiers
import os

class BingGalleryModel: GalleryModelProtocol {
    var images: [NamedBingImage] = []
    var config: Config? = nil
    var reloadStrategy: any ImageReloadStrategy

    var galleryName: String { "Bing" }

    init(loadImages: Bool = true) {
        self.reloadStrategy = ImageReloadByDate()
        if loadImages {
            initializeEnvironment()
            reloadImages()
        }
     
    }
}
