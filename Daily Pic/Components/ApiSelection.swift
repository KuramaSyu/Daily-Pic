//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

public enum WallpaperApiEnum: String, Codable, Hashable, CaseIterable, Identifiable {
    case osu = "osu!"
    case bing = "Bing"

    public var id: String { rawValue }
    public static var allCases: [WallpaperApiEnum] { [.bing, .osu] }
}
struct ApiButton: View {
    let imageName: String
    let action: () -> Void
    let currentlySelected: WallpaperApiEnum
    public let label: WallpaperApiEnum
    /// Drives the selected-button tint from the live wallpaper accent.
    @ObservedObject private var accentStore = AccentColorStore.shared

    init(
        imageName: String,
        label: WallpaperApiEnum,
        currentlySelected: WallpaperApiEnum,
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.currentlySelected = currentlySelected
        self.action = action
        self.label = label
    }

    public var body: some View {
        let isSelected = self.currentlySelected == self.label;

        Button(action: action) {
            HStack {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)

                Text(self.label.rawValue)
                    .frame(maxWidth: .infinity)
            }
            .padding(5)
            // Foreground flips to the contrast color so the label stays
            // readable on top of the accent fill when this button is selected.
            .foregroundStyle(isSelected ? AccentColorStore.contrastColor(for: accentStore.color) : Color.primary)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? accentStore.color : Color.black.opacity(0.5))
        )
    }
}


public struct ApiSelection: View {
    @Binding var selectedApi: WallpaperApiEnum
    
    public init(selectedApi: Binding<WallpaperApiEnum>) {
        self._selectedApi = selectedApi
    }
    
    public var body: some View {
        HStack() {

            // osu! button
            ApiButton(
                imageName: "osu",
                label: WallpaperApiEnum.osu,
                currentlySelected: self.selectedApi,
                action: { self.selectedApi = .osu}
            )

            
            // bing button
            ApiButton(
                imageName: "bing",
                label: WallpaperApiEnum.bing,
                currentlySelected: self.selectedApi,
                action: { self.selectedApi = .bing}
            )

        }
        //.frame(maxWidth: .infinity)
        //.padding(.horizontal, 2)
    }
}
