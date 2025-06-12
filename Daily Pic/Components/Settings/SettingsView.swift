import SwiftUI

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
enum SettingsCategory: String, CaseIterable {
    case general = "General"
    case bing = "Bing"
    case osu = "osu!"
    
    var iconName: String {
        switch self {
        case .general: return "gearshape"
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
            sidebarHeader
            categoryList
            Spacer()
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
    }
    
    private var sidebarHeader: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private var categoryList: some View {
        VStack(spacing: 2) {
            ForEach(SettingsCategory.allCases, id: \.self) { category in
                categoryButton(for: category)
            }
        }
        .padding(.top, 8)
    }
    
    private func categoryButton(for category: SettingsCategory) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            categoryButtonContent(for: category)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
    }
    
    private func categoryButtonContent(for category: SettingsCategory) -> some View {
        let isSelected = selectedCategory == category
        
        return HStack(spacing: 10) {
            Image(systemName: category.iconName)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 16)
            
            Text(category.rawValue)
                .foregroundColor(isSelected ? .white : .primary)
                .font(.system(size: 13))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ?
            Color.accentColor :
            Color.clear
        )
        .cornerRadius(6)
    }
}

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

// MARK: - General Settings View
struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("refreshInterval") private var refreshInterval = 60.0
    @AppStorage("selectedTheme") private var selectedTheme = "System"
    
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

// MARK: - Helper Views
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

#Preview {
    SettingsView()
        .frame(width: 650, height: 500)
}
