//
//  ImageNavigation.swift
//  DailyPic
//
//  Created by Paul Zenker on 23.11.24.
//

import SwiftUI

struct ApiButton: View {
    let imageName: String
    let action: () -> Void
    let isDisabled: Bool
    public let label: String
    
    init(
        imageName: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.isDisabled = isDisabled
        self.action = action
        self.label = label
    }
    
    public var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: imageName)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .opacity(isDisabled ? 0.2 : 1)
            }
            .padding()
            Text(self.label)
        }

        .scaledToFill()
        .layoutPriority(1)
        .buttonStyle(.borderless)
        .hoverEffect()
        .disabled(isDisabled)
    }
}


public struct ApiSelection: View {
    @State public var selectedApi: String?
    
    
    public var body: some View {
        HStack() {

            // osu! button
            ApiButton(
                imageName: "dice",
                label: "osu!",
                isDisabled: false,
                action: { self.selectedApi = "osu"}
            )
            
            // osu! button
            ApiButton(
                imageName: "dice",
                label: "Bing",
                isDisabled: false,
                action: { self.selectedApi = "bing"}
            )
            
            
        }
        .padding(.horizontal, 6)
    }
}
