//
//  ApiScheduleView.swift
//  Daily Pic
//
//  API-by-time-of-day scheduling pane: master switch, default API, "next
//  change" banner, and a stack of per-rule editors.
//

import SwiftUI
import AppKit

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

// One rule: API choice + start/end time + weekday selector + segment editor.
// The rule is rendered as an elevated card with a header strip; segments sit
// in a recessed Image Selection subsection and each segment is its own
// elevated card so rule / subsection / segment read as three depths.
struct ApiScheduleRuleEditor: View {
    @Binding var rule: ApiScheduleRule
    /// Re-renders the weekday dots when the wallpaper-derived accent color changes.
    @ObservedObject private var accentStore = AccentColorStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ruleHeader

            // Rule-level body: API picker, From/To time, weekday mask.
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            // Image Selection subsection: recessed gray surface nested inside
            // the rule so each segment "floats" higher than its container.
            ImageSelectionSegmentsEditor(rule: $rule)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.12))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    // Accent-stripe header that marks the rule boundary and previews the
    // window so users can tell multiple rules apart at a glance.
    private var ruleHeader: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentStore.color)
                .frame(width: 4, height: 14)

            Text("RULE")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.5)
                .foregroundColor(.secondary)

            Text(rule.api.rawValue)
                .font(.caption)
                .fontWeight(.semibold)

            Spacer()

            Text("\(formatMinute(rule.startMinute)) -> \(formatMinute(rule.endMinute))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.10))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func formatMinute(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }
}