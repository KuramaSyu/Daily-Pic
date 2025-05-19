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
    var config: Config? = nil
    
    var galleryName: String { "Bing" }

    init() {
        initializeEnvironment()
        reloadImages()
    }
}
