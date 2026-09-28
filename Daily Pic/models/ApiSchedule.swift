//
//  ApiSchedule.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.09.26.
//

import Foundation
import SwiftUI

// Time range for a rule, expressed in minutes since midnight (0..1439).
// startMinute <= endMinute means a same-day range; otherwise the range
// wraps past midnight (e.g. 22:00 -> 06:00).
struct ApiScheduleRule: Codable, Identifiable, Equatable {
    var id: UUID
    var startMinute: Int
    var endMinute: Int
    // Calendar.weekday values: 1=Sunday ... 7=Saturday.
    // Empty set means "any day".
    var weekdays: Set<Int>
    var api: WallpaperApiEnum

    init(
        id: UUID = UUID(),
        startMinute: Int = 0,
        endMinute: Int = 16 * 60,
        weekdays: Set<Int> = Set(1...7),
        api: WallpaperApiEnum = .bing
    ) {
        self.id = id
        self.startMinute = max(0, min(1439, startMinute))
        self.endMinute = max(0, min(1439, endMinute))
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.api = api
    }

    func matches(date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let hour = comps.hour,
              let minute = comps.minute,
              let weekday = comps.weekday else {
            return false
        }
        let nowMinute = hour * 60 + minute
        let inRange: Bool
        if startMinute <= endMinute {
            inRange = nowMinute >= startMinute && nowMinute < endMinute
        } else {
            inRange = nowMinute >= startMinute || nowMinute < endMinute
        }
        guard inRange else { return false }
        if weekdays.isEmpty { return true }
        return weekdays.contains(weekday)
    }
}

// Singleton store: rules live in UserDefaults under apiSchedule* keys.
// The minute timer in DailyPicApp calls resolve(for:) to drive the active API.
final class ApiScheduleStore: ObservableObject {
    static let shared = ApiScheduleStore()

    private static let enabledKey = "apiScheduleEnabled"
    private static let defaultApiKey = "apiScheduleDefault"
    private static let rulesKey = "apiScheduleRules"

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }
    @Published var defaultApi: WallpaperApiEnum {
        didSet { UserDefaults.standard.set(defaultApi.rawValue, forKey: Self.defaultApiKey) }
    }
    @Published var rules: [ApiScheduleRule] {
        didSet { persistRules() }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.enabledKey) == nil {
            self.enabled = false
        } else {
            self.enabled = defaults.bool(forKey: Self.enabledKey)
        }
        if let raw = defaults.string(forKey: Self.defaultApiKey),
           let api = WallpaperApiEnum(rawValue: raw) {
            self.defaultApi = api
        } else {
            self.defaultApi = .bing
        }
        if let data = defaults.data(forKey: Self.rulesKey),
           let decoded = try? JSONDecoder().decode([ApiScheduleRule].self, from: data) {
            self.rules = decoded
        } else {
            self.rules = []
        }
    }

    private func persistRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Self.rulesKey)
    }

    // Last schedule re-evaluation. The UI reads this to render the "next
    // scheduled change" caption; the heartbeat ticks it every minute so
    // SwiftUI re-renders without binding to `Date` directly.
    @Published private(set) var nextChange: ScheduledChange?

    func resolve(for date: Date = Date()) -> WallpaperApiEnum {
        for rule in rules where rule.matches(date: date) {
            return rule.api
        }
        return defaultApi
    }

    // Recompute the next (api, at) pair from now forward. Returns nil when
    // the schedule is disabled or has no rules.
    func recomputeNextChange(now: Date = Date()) {
        guard enabled, !rules.isEmpty else {
            if nextChange != nil { nextChange = nil }
            return
        }
        let upcoming = Self.nextScheduledChange(
            from: now,
            rules: rules,
            defaultApi: defaultApi
        )
        if upcoming != nextChange {
            nextChange = upcoming
        }
    }

    // Walk forward minute-by-minute up to 8 days to find the next boundary
    // where the active API differs from the one in effect right now. Cheap
    // enough to run once per minute; a typical week has at most a handful
    // of boundaries.
    static func nextScheduledChange(
        from now: Date,
        rules: [ApiScheduleRule],
        defaultApi: WallpaperApiEnum
    ) -> ScheduledChange? {
        let cal = Calendar.current
        let current = Self.resolveAt(now, rules: rules, defaultApi: defaultApi)
        // Search up to 7 days + 1 minute. Wrap-past-midnight ranges mean a
        // boundary can be up to 24h away; 7d covers weekday boundaries too.
        let stride: TimeInterval = 60
        var t = now.addingTimeInterval(stride)
        let horizon = now.addingTimeInterval(7 * 24 * 3600 + stride)
        while t <= horizon {
            let api = Self.resolveAt(t, rules: rules, defaultApi: defaultApi)
            if api != current {
                return ScheduledChange(api: api, at: t)
            }
            t = t.addingTimeInterval(stride)
        }
        return nil
    }

    static func resolveAt(
        _ date: Date,
        rules: [ApiScheduleRule],
        defaultApi: WallpaperApiEnum
    ) -> WallpaperApiEnum {
        for rule in rules where rule.matches(date: date) {
            return rule.api
        }
        return defaultApi
    }
}

// One future plan the UI can render in the menu banner.
struct ScheduledChange: Equatable {
    let api: WallpaperApiEnum
    let at: Date

    // Compact "in 2h 13m" / "in 18m" / "in 45s" rendering.
    func relativeDescription(now: Date = Date()) -> String {
        let delta = max(0, at.timeIntervalSince(now))
        let total = Int(delta.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "in \(h)h \(m)m" }
        if m > 0 { return "in \(m)m" }
        return "in \(total)s"
    }
}

// Helpers to format minute-of-day as Date so SwiftUI DatePicker can bind it.
extension ApiScheduleRule {
    func startDate(for day: Date = Date()) -> Date {
        Self.date(forMinute: startMinute, on: day)
    }
    func endDate(for day: Date = Date()) -> Date {
        Self.date(forMinute: endMinute, on: day)
    }
    mutating func setStart(from date: Date) {
        startMinute = Self.minuteOfDay(from: date)
    }
    mutating func setEnd(from date: Date) {
        endMinute = Self.minuteOfDay(from: date)
    }

    static func date(forMinute minute: Int, on day: Date) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: day)
        return base.addingTimeInterval(TimeInterval(max(0, min(1439, minute)) * 60))
    }
    static func minuteOfDay(from date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}

// Hidden view that ticks every minute and recomputes the schedule store's
// `nextChange`. Manual API picks are always allowed; this view never
// overwrites the binding itself. Lives inside MenuBarExtra's content so
// it inherits the scene lifetime; renders nothing visible.
struct ApiScheduleHeartbeat: View {
    @ObservedObject var store: ApiScheduleStore

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { store.recomputeNextChange() }
            .onChange(of: store.enabled) { _, _ in store.recomputeNextChange() }
            .onChange(of: store.rules) { _, _ in store.recomputeNextChange() }
            .onChange(of: store.defaultApi) { _, _ in store.recomputeNextChange() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    store.recomputeNextChange()
                }
            }
    }
}
