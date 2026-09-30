//
//  SettingsHelpers.swift
//  Daily Pic
//
//  Small reusable building blocks used across the settings panes.
//

import SwiftUI
import AppKit

// MARK: - Visual Effect View for Blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Helper Views

// Titled card that groups a stack of SettingsRows. Single-file declarations
// keep every pane visually consistent.
struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            VStack(spacing: 1) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
}

// One horizontal row inside a SettingsGroup. Standard padding so groups
// read as a unified list even when each row has very different content.
struct SettingsRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Shared schedule helpers

// Calendar.weekday ordering 1=Sun..7=Sat -> localized display labels.
// Exposed as `internal` (no `private`) because both the schedule editor
// and the segments editor need to read it.
let weekdayOrder: [(weekday: Int, label: String, symbol: String)] = [
    (1, "Sun", "S"),
    (2, "Mon", "M"),
    (3, "Tue", "T"),
    (4, "Wed", "W"),
    (5, "Thu", "T"),
    (6, "Fri", "F"),
    (7, "Sat", "S"),
]