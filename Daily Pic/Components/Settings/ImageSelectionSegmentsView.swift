//
//  ImageSelectionSegmentsView.swift
//  Daily Pic
//
//  Sub-editor for the image-picker segments inside one rule's window, plus
//  the chip-style Duration / Re-roll picker used by each segment row.
//

import SwiftUI
import AppKit

// Sub-editor for the image-selection segments inside one rule's window.
// Lets the user mix "newest, then random, ..." by adding segments in order.
struct ImageSelectionSegmentsEditor: View {
    @Binding var rule: ApiScheduleRule
    @ObservedObject private var imageStore = ImageSelectionScheduleStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("IMAGE SELECTION")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .tracking(0.5)
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
                if rule.segments.count == 1 {
                    Text("Covers the full \(formatMinutes(ruleWindowLength)) window.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let total = segmentsTotal, total < ruleWindowLength {
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
                    Label("Add Segment", systemImage: "plus.circle.fill")
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
            .padding(.top, 4)
            .overlay(alignment: .top, content: {
                if !rule.segments.isEmpty {
                    Divider()
                }
            })
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

// One row in the segments editor: mode picker + Duration chip picker +
// (random-only) Re-roll chip picker + delete. Each row is an elevated card
// so it visually pops above the recessed Image Selection container.
struct ImageSelectionSegmentRow: View {
    @Binding var rule: ApiScheduleRule
    @Binding var segment: ImageSelectionSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Numbered chip so multiple segments read as an ordered list
                // and it's obvious where a new one would slot in.
                Text("\(segmentIndex)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.gray.opacity(0.18)))

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

            // Duration is not important for a single segment
            if rule.segments.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Duration:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    DurationChipPicker(
                        minutes: $segment.durationMinutes,
                        presets: [30, 60, 120, 180],
                        range: 5...1440,
                        step: 5
                    )
                }
            } else {
                // With a single segment the model always returns it for the
                // whole window, so duration would just duplicate "Re-roll every".
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .foregroundColor(.secondary)
                    Text("Full window")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            if segment.mode == .random {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Re-roll every:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    DurationChipPicker(
                        minutes: $segment.randomRotationMinutes,
                        presets: [30, 60, 120, 180],
                        range: 0...1440,
                        step: 5,
                        zeroLabel: "once"
                    )
                }
                Text("Custom = any value in 5-minute steps. Otherwise a new random image every N minutes within this segment.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    // 1-based position of this segment inside rule.segments so the chip
    // stays accurate even after a delete in the middle of the list.
    private var segmentIndex: Int {
        (rule.segments.firstIndex { $0.id == segment.id } ?? 0) + 1
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// Chip-style picker for minute values: a row of preset buttons (30m / 1h /
// 2h / 3h) plus a "Custom" chip that reveals a small stepper for arbitrary
// values in <range>. The Custom chip stays selected whenever the current
// value doesn't match any preset, so the user always sees how to come back.
struct DurationChipPicker: View {
    @Binding var minutes: Int
    let presets: [Int]
    let range: ClosedRange<Int>
    let step: Int
    var zeroLabel: String? = nil

    @State private var showCustom: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { preset in
                chip(
                    label: chipLabel(for: preset),
                    selected: minutes == preset
                ) {
                    minutes = preset
                }
            }
            chip(
                label: customLabel,
                selected: isCustomSelected
            ) {
                showCustom = true
            }
        }
        .popover(isPresented: $showCustom, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom duration")
                    .font(.caption)
                    .fontWeight(.medium)
                Stepper(
                    value: $minutes,
                    in: range,
                    step: step
                ) {
                    Text(formatMinutes(minutes))
                        .monospacedDigit()
                }
                .labelsHidden()
                Text("\(range.lowerBound) min … \(formatMinutes(range.upperBound)) in \(step)-minute steps.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(minWidth: 180)
        }
    }

    private var isCustomSelected: Bool {
        !presets.contains(minutes)
    }

    private var customLabel: String {
        if let z = zeroLabel, minutes == 0 { return z }
        return isCustomSelected ? formatMinutes(minutes) : "Custom"
    }

    private func chipLabel(for minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return formatMinutes(minutes)
    }

    @ViewBuilder
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(selected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}