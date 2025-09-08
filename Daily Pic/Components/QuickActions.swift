//
//  QuickActions.swift
//  DailyPic
//
//  Created by Paul Zenker on 21.11.24.
//

import SwiftUI

struct RefreshButton<VM: GalleryViewModelProtocol, IM: ImageTrackerProtocol>: View {
    @ObservedObject var imageManager: VM
    @ObservedObject var imageTracker: IM

    var alignment: Alignment
    var padding: CGFloat
    var height: CGFloat?
    
    var body: some View {
        // Refresh Now Button
        Button(action: {
            Task{ let _ = try await imageTracker.downloadMissingImages(from: nil, reloadImages: false)}
        }) { HStack {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.title2)
                Text("Refresh Now")
                    .font(.body)
            }
            
        }
        .frame(maxWidth: .infinity, minHeight: height ?? nil, alignment: alignment)
        .buttonStyle(.borderless)
        .padding(padding)
        .hoverEffect()
    }
}


struct QuickActions<VM: GalleryViewModelProtocol, IM: ImageTrackerProtocol>: View {
    @State private var isExpanded = false
    @ObservedObject var imageManager: VM
    @ObservedObject var imageTracker: IM
    @Binding var api: WallpaperApiEnum
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .center) {
                
                // Refresh Now Button
                RefreshButton(imageManager: imageManager, imageTracker: imageTracker, alignment: .leading, padding: 1)
                
                // Wallpaper Button
                Button(action: {
                    if let url = imageManager.currentImageUrl {
                        WallpaperHandler().setWallpaper(image: url)
                    }
                }) { HStack {
                        Image(systemName: "photo.tv")
                            .font(.title2)
                        Text("Set as Wallpaper")
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.borderless)
                .padding(1)
                .hoverEffect()
                
                // Open Folder
                Button(action: {imageManager.openFolder()}) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                        Text("Open Folder")
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.borderless)
                .padding(1)
                .hoverEffect()
                
                // Exit App
                Button(action: {
                    NSApplication.shared.terminate(nil) // Shuts down the app
                }) { HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                        Text("Quit")
                            .font(.body)
                    }
                
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.borderless)
                .padding(1)
                .hoverEffect()
                
                ApiSelection(selectedApi: $api).scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.borderless)
                    .padding(1)
                    .hoverEffect()
            }
        } label: {
            Text("Quick Actions")
                .font(.headline)
                .padding(.leading, 6)
                .padding(2)
        }
        .padding(.vertical, 6)  // padding from last toggle to bottom
        .padding(.horizontal, 10)  // padding at left for > and for buttons
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .contentShape(Rectangle()) // Makes the entire label tappable
        .onTapGesture {
            withAnimation { isExpanded.toggle() }
        }
        .onDisappear {
            isExpanded = false
        }
    }
}
