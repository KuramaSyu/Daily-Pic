//
//  SettingsView.swift
//  Daily Pic
//
//  Top-level settings screen: sidebar of categories + the active pane.
//  Helper widgets live in SettingsHelpers.swift; per-pane views in
//  ApiScheduleView.swift / ImageSelectionSegmentsView.swift.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SettingsSidebar(selectedCategory: $selectedCategory)
                .frame(width: 180)

            // Main content area
            VStack(alignment: .leading) {
                // Content based on selected category
                switch selectedCategory {
                case .general:
                    GeneralSettingsView()
                case .apiSchedule:
                    ApiScheduleSettingsView()
                case .bing:
                    BingSettingsView()
                case .osu:
                    OsuSettingsView()
                }

                Spacer()

                // Footer with Done button
                HStack {
                    Spacer()
                    Button("Done") {
                        SettingsWindowController.shared.hideSettings()
                    }
                    .keyboardShortcut(.escape)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 650, minHeight: 500)
    }
}

// MARK: - Settings Categories

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case apiSchedule = "API Schedule"
    case bing = "Bing"
    case osu = "osu!"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .apiSchedule: return "calendar.badge.clock"
        case .bing: return "magnifyingglass"
        case .osu: return "gamecontroller"
        }
    }
}

// MARK: - Sidebar

struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App header
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Pic")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Category list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: category.symbol)
                                    .frame(width: 20)
                                    .foregroundColor(.secondary)
                                Text(category.rawValue)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                            )
                            .cornerRadius(6)
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("refreshInterval") private var refreshInterval = 60.0
    @AppStorage("selectedTheme") private var selectedTheme = "System"
    /// Live view of the active gallery VM + tracker so the action buttons
    /// reach whatever the menu is currently showing.
    @ObservedObject private var depsStore = DependenciesStore.shared
    /// Reflects the menu's auto-apply toggle so the description text stays
    /// consistent with the quicksettings "Set as Wallpaper" visibility.
    @ObservedObject private var autoApplyStore = WallpaperAutoApplyStore.shared

    private let themes = ["System", "Light", "Dark"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Configure general application settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Settings groups
                VStack(spacing: 16) {
                    SettingsGroup("Startup") {
                        SettingsRow {
                            Toggle("Launch at login", isOn: $launchAtLogin)
                        }
                    }

                    SettingsGroup("Notifications") {
                        SettingsRow {
                            Toggle("Show notifications", isOn: $showNotifications)
                        }
                    }

                    SettingsGroup("Appearance") {
                        SettingsRow {
                            HStack {
                                Text("Theme:")
                                Spacer()
                                Picker("Theme", selection: $selectedTheme) {
                                    ForEach(themes, id: \.self) { theme in
                                        Text(theme).tag(theme)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }
                        }
                    }

                    SettingsGroup("Performance") {
                        SettingsRow {
                            HStack {
                                Text("Refresh interval:")
                                Spacer()
                                Slider(
                                    value: $refreshInterval,
                                    in: 30...300,
                                    step: 30
                                ) {
                                    Text("Refresh Interval")
                                }
                                .frame(width: 150)
                                Text("\(Int(refreshInterval))s")
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }

                    SettingsGroup("Actions") {
                        SettingsRow {
                            HStack {
                                Text("Fetch Now")
                                    .fontWeight(.medium)
                                Spacer()
                                Button {
                                    let tracker = depsStore.imageTracker
                                    Task {
                                        _ = try await tracker?.downloadMissingImages(from: nil, reloadImages: false)
                                    }
                                } label: {
                                    Label("Fetch", systemImage: "icloud.and.arrow.down")
                                }
                                .disabled(depsStore.imageTracker == nil)
                                .help("Download any missing images from the active API.")
                            }
                        }
                        SettingsRow {
                            HStack {
                                Text("Open Folder")
                                    .fontWeight(.medium)
                                Spacer()
                                Button {
                                    depsStore.imageManager?.openFolder()
                                } label: {
                                    Label("Open", systemImage: "folder.fill")
                                }
                                .disabled(depsStore.imageManager == nil)
                                .help("Reveal the image folder in Finder.")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Bing Settings View

struct BingSettingsView: View {
    @AppStorage("bingEnabled") private var bingEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bing")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Configure Bing search integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Settings
                VStack(spacing: 16) {
                    SettingsGroup("Integration") {
                        SettingsRow {
                            Toggle("Enable Bing integration", isOn: $bingEnabled)
                        }
                    }

                    if bingEnabled {
                        SettingsGroup("Status") {
                            SettingsRow {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Bing integration is active")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - osu! Settings View

struct OsuSettingsView: View {
    @ObservedObject private var osuSettings = OsuSettingsStore();

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("osu!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Configure osu! API integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Settings
                VStack(alignment: .leading) {
                    SettingsGroup("Integration") {
                        SettingsRow {
                            Toggle("Enable osu! integration", isOn: $osuSettings.isEnabled)
                        }
                    }

                    if osuSettings.isEnabled {
                        SettingsGroup("API Configuration") {
                            VStack(spacing: 12) {
                                SettingsRow {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("API Client ID")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                        TextField("Enter your API Client ID", text: $osuSettings.apiId)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }

                                SettingsRow {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("API Client Secret")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                        SecureField("Enter your API Client Secret", text: $osuSettings.apiSecret)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                            }
                        }

                        SettingsGroup("Help") {
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("To get your API credentials:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("1. Visit https://osu.ppy.sh/home/account/edit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("2. Navigate to OAuth section")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("3. Create a new OAuth application")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 650, height: 500)
}