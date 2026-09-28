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
    @ObservedObject private var scheduleStore = ApiScheduleStore.shared
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .center) {
                
                // Refresh Now Button
                RefreshButton(imageManager: imageManager, imageTracker: imageTracker, alignment: .leading, padding: 1)
                
                // Wallpaper Button
                Button(action: {
                    if let url = imageManager.currentImageUrl {
                        Task{ await WallpaperHandler().setWallpaper(image: url)}
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
                
                ApiSelection(selectedApi: $api)
                    .frame(maxWidth: .infinity)
                    .help(scheduleStore.enabled ? "Manual override — schedule will take over later" : "Switch API manually")
                if scheduleStore.enabled, let next = scheduleStore.nextChange {
                    ScheduleBanner(api: api, next: next)
                }
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

// Banner shown above the manual picker when the API schedule is enabled.
// Tells the user when the next scheduled API switch will fire, and if
// they've manually overridden, that the schedule will retake over.
struct ScheduleBanner: View {
    let api: WallpaperApiEnum
    let next: ScheduledChange

    var body: some View {
        let overridden = api != next.api
        HStack(spacing: 6) {
            Image(systemName: overridden ? "calendar.badge.exclamationmark" : "calendar.badge.clock")
                .foregroundColor(overridden ? .orange : .secondary)
            if overridden {
                Text("Manual: \(api.rawValue). Schedule: \(next.api.rawValue) \(next.relativeDescription())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Schedule: \(next.api.rawValue) \(next.relativeDescription())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}
