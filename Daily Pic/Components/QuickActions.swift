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
                ImageSelectionModeRow(imageManager: imageManager, api: api)
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

// Compact row that shows the schedule's currently-active image-selection
// segment and lets the user fire that mode immediately. Mirrors the
// advisory behaviour of the API schedule: manual picks always win until
// the next segment boundary.
struct ImageSelectionModeRow<VM: GalleryViewModelProtocol>: View {
    @ObservedObject var imageManager: VM
    let api: WallpaperApiEnum
    @ObservedObject private var scheduleStore = ApiScheduleStore.shared
    @ObservedObject private var imageStore = ImageSelectionScheduleStore.shared

    var body: some View {
        let segment = currentSegment
        HStack(spacing: 6) {
            Image(systemName: segment?.mode.symbol ?? "sparkles")
                .foregroundColor(.secondary)
            if let segment {
                Text("\(segment.mode.rawValue) image")
                    .font(.caption)
                    .foregroundColor(.primary)
            } else {
                Text("Manual image selection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                ForEach(ImageSelectionMode.allCases) { mode in
                    Button {
                        apply(mode: mode)
                    } label: {
                        Label(mode.rawValue, systemImage: mode.symbol)
                    }
                }
                if imageStore.randomFavoritesOnly {
                    Divider()
                    Button {
                        apply(mode: .random)
                    } label: {
                        Label("Random favorites", systemImage: "star")
                    }
                }
            } label: {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Apply this image-selection mode now (schedule takes back over at the next segment boundary).")
        }
        .padding(.horizontal, 4)
        .help(segment?.mode.help ?? "No image-selection schedule configured for this rule.")
    }

    private var currentSegment: ImageSelectionSegment? {
        guard scheduleStore.enabled else { return nil }
        let rule = scheduleStore.matchingRule(for: Date())
        guard !rule.segments.isEmpty else { return nil }
        guard let minute = ImageSelectionScheduleStore.minuteIntoRule(date: Date(), rule: rule) else { return nil }
        return ImageSelectionScheduleStore.activeSegment(in: rule.segments, atMinute: minute)
    }

    private func apply(mode: ImageSelectionMode) {
        let rule = scheduleStore.matchingRule(for: Date())
        let segment = ImageSelectionSegment(durationMinutes: 60, mode: mode)
        imageManager.applyScheduledImageSelection(
            rule: ApiScheduleRule(
                id: rule.id,
                startMinute: rule.startMinute,
                endMinute: rule.endMinute,
                weekdays: rule.weekdays,
                api: api,
                segments: [segment]
            ),
            now: Date(),
            store: imageStore
        )
    }
}
