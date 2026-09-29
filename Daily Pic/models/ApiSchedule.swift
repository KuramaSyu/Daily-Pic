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
// `segments` further subdivides the rule's window by image-selection mode.
// When empty, no schedule-driven image picking happens for this rule
// (the menu keeps whatever image is currently displayed).
public struct ApiScheduleRule: Codable, Identifiable, Equatable {
    public var id: UUID
    var startMinute: Int
    var endMinute: Int
    // Calendar.weekday values: 1=Sunday ... 7=Saturday.
    // Empty set means "any day".
    var weekdays: Set<Int>
    var api: WallpaperApiEnum
    // Ordered image-selection segments applied while this rule is active.
    // Decoded with a default of [] so existing persisted rules (added
    // before this property existed) keep working unchanged.
    var segments: [ImageSelectionSegment]

    // Custom decoder keeps the property optional in the persisted JSON so
    // older rules that pre-date `segments` deserialize cleanly.
    private enum CodingKeys: String, CodingKey {
        case id, startMinute, endMinute, weekdays, api, segments
    }

    init(
        id: UUID = UUID(),
        startMinute: Int = 0,
        endMinute: Int = 16 * 60,
        weekdays: Set<Int> = Set(1...7),
        api: WallpaperApiEnum = .bing,
        segments: [ImageSelectionSegment] = []
    ) {
        self.id = id
        self.startMinute = max(0, min(1439, startMinute))
        self.endMinute = max(0, min(1439, endMinute))
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.api = api
        self.segments = segments
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.startMinute = try c.decode(Int.self, forKey: .startMinute)
        self.endMinute = try c.decode(Int.self, forKey: .endMinute)
        self.weekdays = try c.decode(Set<Int>.self, forKey: .weekdays)
        self.api = try c.decode(WallpaperApiEnum.self, forKey: .api)
        self.segments = (try? c.decode([ImageSelectionSegment].self, forKey: .segments)) ?? []
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

    // Next boundary where the active API itself changes. The manual-override
    // lock uses this so an override on <bing> survives a bing-to-bing rule
    // handoff and only expires when the API actually flips.
    @Published private(set) var nextApiChange: ScheduledChange?

    func resolve(for date: Date = Date()) -> WallpaperApiEnum {
        for rule in rules where rule.matches(date: date) {
            return rule.api
        }
        return defaultApi
    }

    // The first rule whose time window matches <date>, or an empty default
    // rule when the schedule is disabled or no rule matches. Callers use
    // this to look up the image-selection segments for the active window.
    func matchingRule(for date: Date = Date()) -> ApiScheduleRule {
        for rule in rules where rule.matches(date: date) {
            return rule
        }
        return ApiScheduleRule()
    }

    // Recompute the next rule boundary from now forward. Returns nil when
    // the schedule is disabled or has no rules. A "boundary" is any minute
    // where the active rule id changes, even if the rule's api stays the
    // same (e.g. bing -> bing across different segments); `changesApi`
    // on the returned ScheduledChange tells callers which case it is.
    func recomputeNextChange(now: Date = Date()) {
        guard enabled, !rules.isEmpty else {
            if nextChange != nil {
                nextChange = nil
                nextApiChange = nil
            }
            return
        }
        let upcoming = Self.nextRuleChange(
            from: now,
            rules: rules,
            defaultApi: defaultApi
        )
        if upcoming != nextChange {
            nextChange = upcoming
        }
        let apiUpcoming = Self.nextScheduledChange(
            from: now,
            rules: rules,
            defaultApi: defaultApi
        )
        if apiUpcoming != nextApiChange {
            nextApiChange = apiUpcoming
        }
    }

    // Walk forward minute-by-minute up to 7 days to find the next boundary
    // where the active rule id differs from the one in effect right now.
    // Cheap enough to run once per minute; a typical week has at most a
    // handful of boundaries.
    static func nextRuleChange(
        from now: Date,
        rules: [ApiScheduleRule],
        defaultApi: WallpaperApiEnum
    ) -> ScheduledChange? {
        let current = Self.activeRule(at: now, rules: rules)
        let currentId = current?.id
        let currentApi = current?.api ?? defaultApi
        // Search up to 7 days + 1 minute. Wrap-past-midnight ranges mean a
        // boundary can be up to 24h away; 7d covers weekday boundaries too.
        let stride: TimeInterval = 60
        var t = now.addingTimeInterval(stride)
        let horizon = now.addingTimeInterval(7 * 24 * 3600 + stride)
        while t <= horizon {
            let next = Self.activeRule(at: t, rules: rules)
            let nextId = next?.id
            if nextId != currentId {
                let nextApi = next?.api ?? defaultApi
                return ScheduledChange(
                    api: nextApi,
                    at: t,
                    changesApi: nextApi != currentApi
                )
            }
            t = t.addingTimeInterval(stride)
        }
        return nil
    }

    // First rule whose window matches <date>; nil when the schedule falls
    // through to the default api (no rule matches).
    static func activeRule(at date: Date, rules: [ApiScheduleRule]) -> ApiScheduleRule? {
        for rule in rules where rule.matches(date: date) {
            return rule
        }
        return nil
    }

    // Walk forward to find the next boundary where the API itself changes.
    // Used by the manual-override lock: a user override should expire at
    // the next api flip, not at every segment rollover inside the same api.
    static func nextScheduledChange(
        from now: Date,
        rules: [ApiScheduleRule],
        defaultApi: WallpaperApiEnum
    ) -> ScheduledChange? {
        let current = resolveAt(now, rules: rules, defaultApi: defaultApi)
        let stride: TimeInterval = 60
        var t = now.addingTimeInterval(stride)
        let horizon = now.addingTimeInterval(7 * 24 * 3600 + stride)
        while t <= horizon {
            let api = resolveAt(t, rules: rules, defaultApi: defaultApi)
            if api != current {
                return ScheduledChange(api: api, at: t, changesApi: true)
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
    // True when the active api changes at <at>. False when only the rule
    // changes (segment mode / random rotation cadence) but api stays put.
    let changesApi: Bool

    init(api: WallpaperApiEnum, at: Date, changesApi: Bool) {
        self.api = api
        self.at = at
        self.changesApi = changesApi
    }

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
        let base = Calendar.current.startOfDay(for: day)
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

/// Background reconciler. Listens for wake / unlock / app-activate events
/// and posts dailyPicReconcileRequest so the app can re-evaluate which
/// api + image should be active.
@MainActor
final class ScheduleReconciler {
    private var wakeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var timerTask: Task<Void, Never>?

    func start() {
        guard wakeObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [fire = self.fire] _ in
            Task { @MainActor in fire("wake") }
        }
        screenObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [fire = self.fire] _ in
            Task { @MainActor in fire("screensDidWake") }
        }
        let distributed = DistributedNotificationCenter.default()
        unlockObserver = distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [fire = self.fire] _ in
            Task { @MainActor in fire("screenUnlocked") }
        }
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [fire = self.fire] _ in
            Task { @MainActor in fire("didActivate") }
        }
        // Background ticker: macOS does not deliver any notification when
        // the schedule crosses a boundary while the user is idle but awake.
        let fireTick = self.fire
        timerTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run { fireTick("tick") }
            }
        }
    }

    /// Called from anywhere on the main actor when reconcile should run.
    /// NotificationCenter dedupes by name, so multiple triggers coalesce.
    func fire(_ reason: String) {
        RuntimeLog.write("reconcile trigger: \(reason)")
        NotificationCenter.default.post(
            name: .dailyPicReconcileRequest,
            object: nil,
            userInfo: ["reason": reason]
        )
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let wakeObserver { center.removeObserver(wakeObserver) }
        if let screenObserver { center.removeObserver(screenObserver) }
        if let activateObserver { center.removeObserver(activateObserver) }
        if let unlockObserver {
            DistributedNotificationCenter.default().removeObserver(unlockObserver)
        }
        timerTask?.cancel()
    }
}
