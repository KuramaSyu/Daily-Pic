//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

struct NavigationButton: View {
    let imageName: String
    let action: () -> Void
    let isDisabled: Bool
    
    init(
        imageName: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: imageName)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .opacity(isDisabled ? 0.2 : 1)
        }
        .scaledToFill()
        .layoutPriority(1)
        .buttonStyle(.borderless)
        .hoverEffect()
        .disabled(isDisabled)
    }
}

public struct ImageNavigation<VM: GalleryViewModelProtocol>: View {
    @ObservedObject var imageManager: VM
    
    
    public var body: some View {
        HStack(spacing: 3) {
            // First Button
            NavigationButton(
                imageName: "arrow.backward.to.line",
                isDisabled: imageManager.isFirstImage(),
                action: {imageManager.showFirstImage()}
            )
            
            // Backward Button
            NavigationButton(
                imageName: "arrow.left",
                isDisabled: imageManager.isFirstImage(),
                action: {imageManager.showPreviousImage()}
            )
            
            // Favorite Button
            NavigationButton(
                imageName: imageManager.isCurrentFavorite() ? "star.fill" : "star",
                isDisabled: false,
                action: {imageManager.makeFavorite( bool: !imageManager.isCurrentFavorite() )}
            )

            // Shuffle Button
            NavigationButton(
                imageName: "dice",
                isDisabled: false,
                action: { imageManager.shuffleIndex() }
            )
            
            // Forward Button
            NavigationButton(
                imageName: "arrow.right",
                isDisabled: imageManager.isLastImage(),
                action: {imageManager.showNextImage()}
            )
            
            // End Button
            NavigationButton(
                imageName: "arrow.forward.to.line",
                isDisabled: imageManager.isLastImage(),
                action: {imageManager.showLastImage()}
            )

        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
    }
}
