//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

public enum WallpaperApiEnum: String {
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
            .padding(8)
            .frame(maxWidth: .infinity)
            .foregroundColor(.clear) // transparent text and image
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isSelected)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }
}
