//
//  AppDependencies.swift
//  Daily Pic
//
//  Created by Paul Zenker on 03.09.25.
//

typealias ZeroArgFactory<T> = () -> T

public class AppDependencies {
    let api: WallpaperApiEnum
    let galleryVM: any GalleryViewModelProtocol
    let gallery: any GalleryModelProtocol
    let imageTracker: any ImageTrackerProtocol
    let wallpaperApi: any WallpaperApiProtocol
    let makeTrackerView: ZeroArgFactory<any ImageTrackerViewProtocol>
    

    init(api: WallpaperApiEnum) {
        self.api = api
        switch api {
        case .bing:
            let gallery = BingGalleryModel(loadImages: true)
            self.gallery = gallery
            self.galleryVM = BingGalleryViewModel(galleryModel: gallery)
            let wallpaperApi = BingWallpaperApi()
            self.wallpaperApi = wallpaperApi
            let makeTrackerView = {BingImageTrackerView(self.galleryVM)}
            self.makeTrackerView = makeTrackerView
            self.imageTracker = BingImageTracker(
                gallery: gallery,
                wallpaperApi: wallpaperApi,
                viewModel: self.galleryVM,
                trackerViewFactory: makeTrackerView
            )
            
            
        case .osu:
            // the "duplicate" let vars have the concrete type
            // rather then the Protocol type. And some deps need
            // the concrete type.
            // Hence it prevents type-casting
            let gallery = OsuGalleryModel(loadImages: true)
            self.gallery = gallery
            self.wallpaperApi = OsuWallpaperApi(gallery_model: gallery)
            let galleryVM = OsuGalleryViewModel(galleryModel: gallery)
            self.galleryVM = galleryVM
            
            let makeTrackerView = {
                OsuImageTrackerView(vm: galleryVM)
            }
            self.makeTrackerView = makeTrackerView
            self.imageTracker = OsuImageTracker(
                gallery: gallery,
                wallpaperApi: wallpaperApi,
                viewModel: galleryVM,
                trackerViewFactory: makeTrackerView
            )
        }
    }
}
