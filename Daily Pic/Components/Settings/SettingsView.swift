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
enum SettingsCategory: String, CaseIterable {
    case general = "General"
    case apiSchedule = "API Schedule"
    case bing = "Bing"
    case osu = "osu!"

    var iconName: String {
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
    /// Re-renders the sidebar when the wallpaper-derived accent color changes.
    @ObservedObject private var accentStore = AccentColorStore.shared

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
            accentStore.color :
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

// MARK: - API Schedule View

// Calendar.weekday ordering 1=Sun..7=Sat -> localized display labels.
private let weekdayOrder: [(weekday: Int, label: String, symbol: String)] = [
    (1, "Sun", "S"),
    (2, "Mon", "M"),
    (3, "Tue", "T"),
    (4, "Wed", "W"),
    (5, "Thu", "T"),
    (6, "Fri", "F"),
    (7, "Sat", "S"),
]

struct ApiScheduleSettingsView: View {
    @ObservedObject private var store = ApiScheduleStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Schedule")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Pick which wallpaper API is active based on the time of day and weekday.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(spacing: 16) {
                    SettingsGroup("Master Switch") {
                        SettingsRow {
                            HStack {
                                Toggle("Schedule API selection by time & weekday", isOn: $store.enabled)
                                Spacer()
                                Text(store.enabled ? "On" : "Off")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        SettingsRow {
                            Text("Manual picks in the menu always win. The schedule is advisory: it shows when the next API switch is planned and quietly retakes over at the next rule boundary.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        SettingsRow {
                            HStack {
                                Text("Default API when no rule matches:")
                                Spacer()
                                Picker("Default API", selection: $store.defaultApi) {
                                    ForEach(WallpaperApiEnum.allCases) { api in
                                        Text(api.rawValue).tag(api)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                                .disabled(!store.enabled)
                            }
                        }
                    }

                    if store.enabled, let next = store.nextChange {
                        SettingsGroup("Next Scheduled Change") {
                            SettingsRow {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.secondary)
                                    Text("\(next.api.rawValue) \(next.relativeDescription())")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(next.at.formatted(date: .omitted, time: .shortened))
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    SettingsGroup("Active Now") {
                        SettingsRow {
                            HStack(spacing: 8) {
                                Image(systemName: store.resolve() == .bing ? "magnifyingglass" : "gamecontroller")
                                Text("Currently using: \(store.resolve().rawValue)")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(Date.now.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }

                    SettingsGroup("Rules") {
                        if store.rules.isEmpty {
                            SettingsRow {
                                Text("No rules yet. The default API is used 24/7.")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        } else {
                            ForEach($store.rules) { $rule in
                                ApiScheduleRuleEditor(rule: $rule)
                            }
                        }
                        SettingsRow {
                            HStack {
                                Spacer()
                                Button {
                                    store.rules.append(ApiScheduleRule())
                                } label: {
                                    Label("Add Rule", systemImage: "plus.circle")
                                }
                                .buttonStyle(.borderless)
                                .disabled(!store.enabled)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ApiScheduleRuleEditor: View {
    @Binding var rule: ApiScheduleRule
    /// Re-renders the weekday dots when the wallpaper-derived accent color changes.
    @ObservedObject private var accentStore = AccentColorStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("API", selection: $rule.api) {
                    ForEach(WallpaperApiEnum.allCases) { api in
                        Text(api.rawValue).tag(api)
                    }
                }
                .labelsHidden()
                .frame(width: 130)

                Spacer()

                Button(role: .destructive) {
                    ApiScheduleStore.shared.rules.removeAll { $0.id == rule.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Text("From")
                    .foregroundColor(.secondary)
                DatePicker(
                    "",
                    selection: Binding(
                        get: { rule.startDate() },
                        set: { rule.setStart(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Text("to")
                    .foregroundColor(.secondary)

                DatePicker(
                    "",
                    selection: Binding(
                        get: { rule.endDate() },
                        set: { rule.setEnd(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                if rule.startMinute > rule.endMinute {
                    Text("wraps past midnight")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                Text("Days:")
                    .foregroundColor(.secondary)
                    .font(.caption)
                ForEach(weekdayOrder, id: \.weekday) { item in
                    let isOn = rule.weekdays.contains(item.weekday)
                    Button {
                        if isOn {
                            rule.weekdays.remove(item.weekday)
                        } else {
                            rule.weekdays.insert(item.weekday)
                        }
                    } label: {
                        Text(item.symbol)
                            .font(.caption)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(isOn ? accentStore.color : Color.gray.opacity(0.25))
                            )
                            .foregroundColor(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    rule.weekdays = rule.weekdays.isEmpty
                        ? Set(1...7)
                        : []
                } label: {
                    Text(rule.weekdays.isEmpty ? "Any day" : (rule.weekdays.count == 7 ? "All days" : "Clear"))
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                Spacer()
            }

            Divider()

            ImageSelectionSegmentsEditor(rule: $rule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// Sub-editor for the image-selection segments inside one rule's window.
// Lets the user mix "newest, then random, ..." by adding segments in order.
struct ImageSelectionSegmentsEditor: View {
    @Binding var rule: ApiScheduleRule
    @ObservedObject private var imageStore = ImageSelectionScheduleStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Image Selection")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text(rule.segments.isEmpty
                     ? "Manual picks only"
                     : "\(rule.segments.count) segment\(rule.segments.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "shuffle")
                    .foregroundColor(.secondary)
                Toggle(
                    "Random mode only picks favorites",
                    isOn: $imageStore.randomFavoritesOnly
                )
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                Spacer()
                Text(imageStore.randomFavoritesOnly ? "favorites only" : "any image")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if rule.segments.isEmpty {
                Text("Add a segment to schedule which image shows during this rule's window.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach($rule.segments) { $segment in
                    ImageSelectionSegmentRow(
                        rule: $rule,
                        segment: $segment
                    )
                }
                if let total = segmentsTotal, total < ruleWindowLength {
                    Text("Last segment repeats to fill the \(formatMinutes(ruleWindowLength)) window.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let total = segmentsTotal, total > ruleWindowLength {
                    Text("Segments exceed the \(formatMinutes(ruleWindowLength)) window; the excess is ignored.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Spacer()
                Button {
                    rule.segments.append(
                        ImageSelectionSegment(
                            offsetMinutes: rule.segments.reduce(0) { $0 + $1.durationMinutes },
                            durationMinutes: 60,
                            mode: .latest
                        )
                    )
                } label: {
                    Label("Add Segment", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                if !rule.segments.isEmpty {
                    Button(role: .destructive) {
                        rule.segments.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
            }
        }
    }

    private var ruleWindowLength: Int {
        ImageSelectionScheduleStore.windowLengthMinutes(rule: rule)
    }

    private var segmentsTotal: Int? {
        guard !rule.segments.isEmpty else { return nil }
        return rule.segments.reduce(0) { $0 + $1.durationMinutes }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// One row in the segments editor: mode picker + duration stepper +
// (random-only) cadence stepper + delete.
struct ImageSelectionSegmentRow: View {
    @Binding var rule: ApiScheduleRule
    @Binding var segment: ImageSelectionSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Picker("", selection: $segment.mode) {
                    ForEach(ImageSelectionMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.symbol).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)

                Spacer()

                Button(role: .destructive) {
                    rule.segments.removeAll { $0.id == segment.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Text("Duration:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Stepper(
                    value: $segment.durationMinutes,
                    in: 5...1440,
                    step: 5
                ) {
                    Text(formatMinutes(segment.durationMinutes))
                        .monospacedDigit()
                }
            }

            if segment.mode == .random {
                HStack(spacing: 8) {
                    Text("Re-roll every:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Stepper(
                        value: $segment.randomRotationMinutes,
                        in: 0...1440,
                        step: 5
                    ) {
                        Text(segment.randomRotationMinutes == 0
                             ? "once"
                             : formatMinutes(segment.randomRotationMinutes))
                            .monospacedDigit()
                    }
                }
                Text("0 = single pick at segment start. Otherwise a new random image every N minutes within this segment.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

#Preview {
    SettingsView()
        .frame(width: 650, height: 500)
}
