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
    var currentImage: imageType? { get }
    var revealNextImage: RevealNextImageViewModel? { get set }
    var currentImageUrl: URL? { get }
    var imageTracker: ImageTrackerProtocol { get set }
    var config: Config { get set}

    
    func isFirstImage() -> Bool
    func showFirstImage()
    func isLastImage() -> Bool
    func showLastImage()
    func showPreviousImage()
    func isCurrentFavorite() -> Bool
    func makeFavorite(bool: Bool)
    func shuffleIndex()
    func showNextImage()
    func openFolder()
    func writeConfig()
    @Sendable static func loadImages(
        revealNextImage: RevealNextImageViewModel?, galleryModel: galleryType,
        imageIterator: inout StrategyBasedImageIterator<imageType>
    )
    @Sendable func selfLoadImages()
    
    
    
}
