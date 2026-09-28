//
//  ImageSelectionSchedule.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.09.26.
//
// Schedule-driven image picker. A schedule rule's time window is subdivided
// into one or more `ImageSelectionSegment`s; each segment picks images
// according to its mode (latest / lastUsed / random). Random mode can
// optionally re-roll on a sub-cadence.

import Foundation
import SwiftUI

// How an image is picked at a given tick.
public enum ImageSelectionMode: String, Codable, CaseIterable, Identifiable {
    case latest = "Latest"
    case lastUsed = "Last used"
    case random = "Random"

    public var id: String { rawValue }

    var symbol: String {
        switch self {
        case .latest: return "sparkles"
        case .lastUsed: return "clock.arrow.circlepath"
        case .random: return "dice"
        }
    }

    var help: String {
        switch self {
        case .latest:
            return "Show the most recently downloaded image."
        case .lastUsed:
            return "Show the image you had open last."
        case .random:
            return "Pick a random image. Optionally re-roll on a cadence."
        }
    }
}

// One sub-block inside an ApiScheduleRule's time window.
// offsetMinutes: minutes from the rule's start (informational; segments are
//   applied in order, not by absolute offset).
// durationMinutes: how long this segment lasts before the next one.
// randomRotationMinutes: when mode == .random, optional sub-cadence
//   (re-pick every N minutes). 0 = single pick at segment start.
public struct ImageSelectionSegment: Codable, Identifiable, Equatable {
    public var id: UUID
    public var offsetMinutes: Int
    public var durationMinutes: Int
    public var mode: ImageSelectionMode
    public var randomRotationMinutes: Int

    public init(
        id: UUID = UUID(),
        offsetMinutes: Int = 0,
        durationMinutes: Int = 60,
        mode: ImageSelectionMode = .latest,
        randomRotationMinutes: Int = 0
    ) {
        self.id = id
        self.offsetMinutes = max(0, offsetMinutes)
        self.durationMinutes = max(1, durationMinutes)
        self.mode = mode
        self.randomRotationMinutes = max(0, randomRotationMinutes)
    }

    // Custom decoder so JSON written before the clamping init (or hand-
    // edited by a user) can never resurrect a segment with
    // durationMinutes <= 0 / negative offsets / negative rotation. The
    // synthesized decoder would assign raw values verbatim and crash the
    // minute-tick heartbeat at `minuteIntoRule % total`.
    private enum CodingKeys: String, CodingKey {
        case id, offsetMinutes, durationMinutes, mode, randomRotationMinutes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.offsetMinutes = max(0, (try? c.decode(Int.self, forKey: .offsetMinutes)) ?? 0)
        self.durationMinutes = max(1, (try? c.decode(Int.self, forKey: .durationMinutes)) ?? 60)
        self.mode = (try? c.decode(ImageSelectionMode.self, forKey: .mode)) ?? .latest
        self.randomRotationMinutes = max(
            0,
            (try? c.decode(Int.self, forKey: .randomRotationMinutes)) ?? 0
        )
    }
}

// Side preferences for the schedule-driven image picker.
public final class ImageSelectionScheduleStore: ObservableObject {
    static let shared = ImageSelectionScheduleStore()

    private static let randomFavoritesOnlyKey = "imageSelectionRandomFavoritesOnly"

    // When random mode is active, restrict to favorites only.
    @Published var randomFavoritesOnly: Bool {
        didSet {
            UserDefaults.standard.set(randomFavoritesOnly, forKey: Self.randomFavoritesOnlyKey)
        }
    }

    private init() {
        randomFavoritesOnly = UserDefaults.standard.bool(forKey: Self.randomFavoritesOnlyKey)
    }

    // Window length in minutes, handling wrap-past-midnight.
    static func windowLengthMinutes(rule: ApiScheduleRule) -> Int {
        if rule.startMinute <= rule.endMinute {
            return rule.endMinute - rule.startMinute
        }
        return (24 * 60 - rule.startMinute) + rule.endMinute
    }

    // Minutes from the rule's start (0..windowLength-1). Wraps modulo the
    // total segment duration so the last segment repeats to fill the gap
    // when segments cover less than the full window.
    static func minuteIntoRule(date: Date, rule: ApiScheduleRule) -> Int? {
        guard rule.matches(date: date) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let h = comps.hour, let mm = comps.minute else { return nil }
        let nowMinute = h * 60 + mm
        if rule.startMinute <= rule.endMinute {
            return nowMinute - rule.startMinute
        }
        // wraps midnight
        if nowMinute >= rule.startMinute {
            return nowMinute - rule.startMinute
        }
        return (24 * 60 - rule.startMinute) + nowMinute
    }

    // Walk the segments in order and return the one active at
    // <minuteIntoRule>. Never traps: drops segments with non-positive
    // durations (defence in depth against legacy / hand-edited JSON that
    // bypassed the clamping init), clamps the minute, and falls back to a
    // sensible segment when nothing usable is left. The minute-tick
    // heartbeat calls this every 60 s so any crash here is a hard fault.
    static func activeSegment(
        in segments: [ImageSelectionSegment],
        atMinute minuteIntoRule: Int
    ) -> ImageSelectionSegment {
        let valid = segments.filter { $0.durationMinutes > 0 }
        let fallback = segments.first ?? ImageSelectionSegment(
            durationMinutes: 1,
            mode: .latest
        )
        guard !valid.isEmpty else { return fallback }
        let total = valid.reduce(into: 0) { $0 += $1.durationMinutes }
        guard total > 0 else { return valid[0] }
        let safeMinute = max(0, minuteIntoRule)
        let m = ((safeMinute % total) + total) % total
        var cursor = 0
        for seg in valid {
            let next = cursor + seg.durationMinutes
            if m < next { return seg }
            cursor = next
        }
        return valid.last!
    }
}
