//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

enum WallpaperApiEnum: String {
    case osu = "osu!"
    case bing = "Bing"
}
struct ApiButton: View {
    let imageName: String
    let action: () -> Void
    let currentlySelected: WallpaperApiEnum
    public let label: WallpaperApiEnum
    
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
        let isDisabled = self.currentlySelected == self.label;
        HStack {
            Button(action: action) {
                Image(systemName: imageName)
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .opacity(isDisabled ? 0.2 : 1)
            }
            Text(self.label.rawValue)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .buttonStyle(.borderless)
        .hoverEffect()
        .disabled(isDisabled)
    }
}


public struct ApiSelection: View {
    @State var selectedApi: WallpaperApiEnum
    
    public init() {
        self.selectedApi = .bing;
    }
    
    public var body: some View {
        HStack() {

            // osu! button
            ApiButton(
                imageName: "dice",
                label: WallpaperApiEnum.osu,
                currentlySelected: self.selectedApi,
                action: { self.selectedApi = .osu}
            )
            
            // bing button
            ApiButton(
                imageName: "dice",
                label: WallpaperApiEnum.bing,
                currentlySelected: self.selectedApi,
                action: { self.selectedApi = .bing}
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, nil)
    }
}
