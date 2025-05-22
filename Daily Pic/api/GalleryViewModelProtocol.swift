//
//  GalleryViewModelProtocol.swift
//  Daily Pic
//
//  Created by Paul Zenker on 22.05.25.
//

public protocol GalleryViewModelProtocol {
    associatedtype imageType: NamedImageProtocol
    associatedtype galleryType: GalleryModelProtocol
    //static var shared: Self { get }
    var image: imageType? { get set }
    var favoriteImages: Set<imageType> { get set }
    var galleryModel: galleryType { get }
}
