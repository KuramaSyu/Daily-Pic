//
//  AppDependencies.swift
//  Daily Pic
//
//  Created by Paul Zenker on 03.09.25.
//

public class AppDependencies {
    let makeGalleryVM: (_ api: WallpaperApiEnum) -> any GalleryViewModelProtocol
    let makeImageTracker: (_ api: WallpaperApiEnum) -> any ImageTrackerProtocol
    
    init(
        makeGalleryVM: @escaping (_: WallpaperApiEnum) -> any GalleryViewModelProtocol,
        makeImageTracker: @escaping (_: WallpaperApiEnum) -> any ImageTrackerProtocol
    ) {
        self.makeGalleryVM = makeGalleryVM
        self.makeImageTracker = makeImageTracker
    }
    static func live() -> AppDependencies {
        AppDependencies(
            makeGalleryVM: { api in
                    switch api {
                    case .bing:
                        return BingGalleryViewModel.shared
                    case .osu:
                        let galleryModel = OsuGalleryModel(loadImages: true)
                        // let wallpaperApi = OsuWallpaperApi(gallery_model: galleryModel)
                        return OsuGalleryViewModel(galleryModel: galleryModel)
                    
                }
            }) { api in
                switch api {
                case .bing:
                    let galleryModel = BingGalleryModel(loadImages: true)
                    let wallpaperApi = BingWallpaperApi()
                    return BingImageTracker(gallery: galleryModel, wallpaperApi: wallpaperApi)
                case .osu:
                    let galleryModel = OsuGalleryModel(loadImages: false)
                    let wallpaperApi = OsuWallpaperApi(gallery_model: galleryModel)
                    let vm = OsuGalleryViewModel(galleryModel: galleryModel)
                    let trackerView = OsuImageTrackerView(vm: vm)
                    return OsuImageTracker(
                        gallery: galleryModel,
                        wallpaperApi: wallpaperApi,
                        viewModel: vm,
                        trackerView: trackerView
                    )
                }
            }
    }
}
