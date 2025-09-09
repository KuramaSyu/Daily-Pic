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
        let isDisabled = self.currentlySelected == self.label;
        
        Button(action: action) {
            HStack {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                
                Text(self.label.rawValue)
            }
        }
        .frame(maxWidth: .infinity)
        .hoverEffect()
        .disabled(isDisabled)
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
            .frame(maxWidth: .infinity)
            
            // bing button
            ApiButton(
                imageName: "bing",
                label: WallpaperApiEnum.bing,
                currentlySelected: self.selectedApi,
                action: { self.selectedApi = .bing}
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
