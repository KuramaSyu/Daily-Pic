//
//  InfoPopover.swift
//  Daily Pic
//
//  Info icon in the menu bar top-right.
//  - Hover preview shows the popover with the latest few entries as cards.
//  - Click pins the popover open.
//  - Copy button copies the bare log format to the pasteboard.

import SwiftUI
import AppKit

extension InfoLogKind {
    /// SF Symbol used inside the card icon circle.
    var symbolName: String {
        switch self {
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    /// Static tint for status kinds. .info defers to the caller's accent
    /// color (the dynamic wallpaper-derived one) so the helper here only
    /// handles the fixed-status kinds.
    var staticTint: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        case .info:    return .accentColor
        }
    }
}

struct InfoLogRow: View {
    let event: InfoLogEvent
    /// Re-renders the row when the wallpaper-derived accent color changes.
    @ObservedObject private var accentStore = AccentColorStore.shared

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Resolves the per-row tint. .info uses the dynamic accent color; the
    /// other kinds use fixed semantic colors.
    private var tint: Color {
        event.kind == .info ? accentStore.color : event.kind.staticTint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                Image(systemName: event.kind.symbolName)
                    .foregroundStyle(tint)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.category)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(Self.timeFormatter.string(from: event.timestamp))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(event.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct InfoPopover: View {
    @ObservedObject var log: InfoLog
    @ObservedObject private var accentStore = AccentColorStore.shared
    @State private var isPinned: Bool = false
    @State private var hoveringIcon: Bool = false
    @State private var hoveringContent: Bool = false
    @State private var copiedAt: Date? = nil

    private var isPresented: Bool {
        isPinned || hoveringIcon || hoveringContent
    }

    /// Latest event kind drives the trigger icon. Default is info.
    /// Errors/warnings get a distinct icon so users notice without opening the popover.
    private var latestKind: InfoLogKind {
        log.events.first?.kind ?? .info
    }

    private var triggerIconName: String {
        switch latestKind {
        case .error:   return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle"
        }
    }

    private var triggerIconTint: Color {
        switch latestKind {
        case .error:   return .red
        case .warning: return .orange
        case .success: return .green
        case .info:    return .primary
        }
    }

    private var triggerHelp: String {
        switch latestKind {
        case .error:   return "Recent errors - click to view"
        case .warning: return "Recent warnings - click to view"
        case .success: return "Recent activity - click to view"
        case .info:    return "Show what DailyPic has checked recently"
        }
    }

    var body: some View {
        Button {
            isPinned.toggle()
        } label: {
            Image(systemName: triggerIconName)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(hoveringIcon ? AccentColorStore.contrastColor(for: accentStore.color) : triggerIconTint)
                .padding(6)
        }
        .background(hoveringIcon ? accentStore.color : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .buttonStyle(PlainButtonStyle())
        .help(triggerHelp)
        .onHover { hoveringIcon = $0 }
        .popover(isPresented: Binding(
            get: { isPresented },
            set: { newValue in
                if !newValue { isPinned = false }
                // Do NOT touch hover flags here. SwiftUI may toggle the
                // binding as the popover's hosting window appears/disappears;
                // we only react to real mouse moves via onHover.
            }
        ), arrowEdge: .top) {
            popoverContent
                .onHover { hoveringContent = $0 }
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            if log.events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("No activity yet.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(log.events) { event in
                            InfoLogRow(event: event)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minWidth: 380, minHeight: 260, maxHeight: 360)
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(accentStore.color)
            Text("DailyPic activity")
                .font(.headline)
            Spacer()
            if isPinned {
                Button("Unpin") { isPinned = false }
                    .buttonStyle(.borderless)
            }
            Button {
                copyToPasteboard()
            } label: {
                Label("Copy", systemImage: copiedRecently ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .help("Copy the bare log to the clipboard")
            .disabled(log.events.isEmpty)
            Button("Clear") { InfoLogCall.clear() }
                .buttonStyle(.borderless)
                .disabled(log.events.isEmpty)
        }
    }

    private var copiedRecently: Bool {
        guard let copiedAt else { return false }
        return Date().timeIntervalSince(copiedAt) < 1.5
    }

    private func copyToPasteboard() {
        let text = log.plainText()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copiedAt = Date()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copiedAt = nil
        }
    }
}
