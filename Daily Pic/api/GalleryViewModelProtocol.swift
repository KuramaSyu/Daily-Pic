//
//  GalleryViewModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 22.05.25.
//
import SwiftUI

public protocol GalleryViewModelProtocol: ObservableObject {
    associatedtype imageType: NamedImageProtocol
    associatedtype galleryType: GalleryModelProtocol
    //static var shared: Self { get }
    var image: imageType? { get set }
    var favoriteImages: Set<imageType> { get set }
    var galleryModel: galleryType { get }
    var currentImage: imageType? { get set }
    var revealNextImage: RevealNextImageViewModel { get set }
}
