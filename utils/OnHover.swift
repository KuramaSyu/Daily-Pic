//
//  OnHover.swift
//  DailyPic
//
//  Created by Paul Zenker on 19.11.24.
//

import SwiftUI


// Custom Modifier for Hover Effect
struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            //.padding()
            .background(isHovered ? Color.gray.opacity(0.2) : Color.clear)
            .foregroundColor(isHovered ? .white : .primary)
            .cornerRadius(8)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
}
