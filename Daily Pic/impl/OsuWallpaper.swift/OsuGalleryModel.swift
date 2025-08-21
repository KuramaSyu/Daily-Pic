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
    var images: [NamedBingImage] = []
    var config: Config? = nil
    var reloadStrategy: any ImageReloadStrategy

    var galleryName: String { "osu" }

    init(loadImages: Bool = true) {
        self.reloadStrategy = ImageReloadByDate()
        if loadImages {
            initializeEnvironment()
            reloadImages()
        }
     
    }
}

