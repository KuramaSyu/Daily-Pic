//
//  ImageTracker.swift
//  Daily Pic
//
//  Created by Paul Zenker on 14.05.25.
//

import Foundation

public protocol ImageTrackerProtocol {
    /// Downloads images <from> dates and triggers image reload afterwards
    /// - Parameters:
    ///     - from dates: Optional array of dates
    ///     - reloadImages: Whether or not to trigger a realod of the images (that view actually shows new images)
    /// - Returns:
    ///     An Array of Dates, from which images where downloaded
    func downloadMissingImages(from dates: [Date]?, reloadImages: Bool) async -> [Date]
    
    init (gallery: any GalleryModelProtocol, wallpaperApi: any WallpaperApiProtocol)
}

protocol ImageTrackerViewProtocol {
    /// triggers a reload of the view, to load the images from file manager
    func reloadImages() async;
    
    /// sets ImageReveal in the GaleryViewModel
    func setImageReveal(date: Date) async;
    
    /// Sets the <message> of the ImageReveal. Usually to display, in which state a download is, triggered by the ImageTracker
    func setImageRevealMessage(message: String) async;
}
