//
//  QuickActions.swift
//  DailyPic
//
//  Created by Paul Zenker on 21.11.24.
//

import SwiftUI

struct QuickActions: View {
    @State private var isExpanded = false
    @State private var toggleOption1 = false
    @State private var toggleOption2 = true
    
    @ObservedObject var imageManager: ImageManager
    
    var body: some View {
        VStack(alignment: .leading) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .listRowSeparatorLeading) {
                    
                    // Refresh Now Button
                    Button(action: {
                        Task{ await imageManager.downloadImageOfToday()}
                    }) { HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.title2)
                            Text("Refresh Now")
                                .font(.body)
                                .scaledToFill()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .padding(1)
                    .hoverEffect()
                    
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
                                .scaledToFill()
                        }
                        .frame(maxWidth: .infinity)
                    }
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
                                .scaledToFill()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .padding(1)
                    .hoverEffect()
                    
                    // Exit App
                    Button(action: {
                        NSApplication.shared.terminate(nil) // Shuts down the app
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                            Text("Quit")
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 1)

                            
                    }
                    //.background(Color.red.opacity(0.2))
                    //.cornerRadius(8)
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 40)
                    .hoverEffect()
                    
                    
                }
                .padding(.leading, 2) // Optional, for visual hierarchy
            } label: {
                Text("Quick Actions")
                    .font(.headline)
                    .padding(6)
                    //.foregroundColor(.blue)
            }
            .padding(6)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
        }
        .padding()
    }
    
}
