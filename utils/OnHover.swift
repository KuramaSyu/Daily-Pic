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

// Accent-aware hover modifier for the small menu-bar icons (info, gear).
// Background flips to the wallpaper-derived accent on hover and the
// foreground swaps to the matching contrast color so icons stay readable
// regardless of which wallpaper is showing.
struct AccentHoverModifier: ViewModifier {
    @State private var isHovered = false
    @ObservedObject private var accentStore = AccentColorStore.shared

    func body(content: Content) -> some View {
        let bg = isHovered ? accentStore.color : Color.clear
        let fg = isHovered
            ? AccentColorStore.contrastColor(for: accentStore.color)
            : Color.primary
        return content
            .background(bg)
            .foregroundStyle(fg)
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

    /// Hover background that follows the dynamic accent color.
    /// Use on the small menu-bar icons where the wallpaper-derived color
    /// should also drive the hover feedback.
    func accentHover() -> some View {
        self.modifier(AccentHoverModifier())
    }
}
