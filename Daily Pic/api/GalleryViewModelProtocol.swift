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
    // var imageTracker: ImageTrackerProtocol { get set }
    var config: Config { get set}

    
    func isFirstImage() -> Bool
    func showFirstImage()
    func isLastImage() -> Bool
    func showLastImage()
    func restoreLastUsedImageOrFallback()
    func showPreviousImage()
    func isCurrentFavorite() -> Bool
    func makeFavorite(bool: Bool)
    func shuffleIndex()
    func showNextImage()
    func openFolder()
    func writeConfig()
    /// Free bitmaps on every image that have been idle longer than <ttl>.
    /// Called periodically from the background so a long-running session
    /// cannot grow the NSImage cache without bound.
    func evictIdleCaches(ttl: TimeInterval)
    /// Apply the schedule's current image-selection segment. Called every
    /// minute from the heartbeat. Re-picks the displayed image only when
    /// the active segment changed (or, for random mode, when the
    /// randomRotationMinutes cadence has elapsed)
    func applyScheduledImageSelection(
        rule: ApiScheduleRule,
        now: Date,
        store: ImageSelectionScheduleStore
    )
    @Sendable static func loadImages(
        revealNextImage: RevealNextImageViewModel?, galleryModel: galleryType,
        imageIterator: inout StrategyBasedImageIterator<imageType>
    )
    @Sendable func selfLoadImages()
    
    
    
}
