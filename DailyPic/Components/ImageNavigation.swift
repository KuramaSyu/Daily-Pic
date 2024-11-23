//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

public struct ImageNavigation: View {
    @ObservedObject var imageManager: ImageManager
    
    
    public var body: some View {
        HStack(spacing: 3) {
            // Backward Button
            Button(action: {
                imageManager.showPreviousImage()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .scaledToFill()
            .layoutPriority(1)
            .buttonStyle(.borderless)
            .hoverEffect()
            
            // Favorite Button
            Button(action: {imageManager.makeFavorite( bool: !imageManager.isCurrentFavorite() )}) {
                Image(systemName: imageManager.isCurrentFavorite() ? "star.fill" : "star")
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .font(.title2)
            }
            .scaledToFill()
            .buttonStyle(.borderless)
            .layoutPriority(1)
            .hoverEffect()
            
            // Forward Button
            Button(action: {
                imageManager.showNextImage()
            }) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .scaledToFill()
            .layoutPriority(1)
            .buttonStyle(.borderless)
            .hoverEffect()
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
    }
}
