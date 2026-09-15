//
//  InfoLog.swift
//  Daily Pic
//
//  In-memory log of user-visible "what did the app check?" events.
//  Backed by a small ring buffer; never written to disk and never
//  forwarded to os_log so the menu-popover stays clean.

import Foundation
import Combine

/// Visual category for an entry. Drives the card icon + tint in the popover.
public enum InfoLogKind: String, Hashable, CaseIterable, Codable {
    case info
    case success
    case warning
    case error
}

/// One user-facing event in the info popover.
public struct InfoLogEvent: Identifiable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let message: String
    public let kind: InfoLogKind

    public init(
        category: String,
        message: String,
        kind: InfoLogKind = .info,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.kind = kind
    }

    /// Bare log line used by the Copy button. No decoration, monospace-friendly.
    public var formatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "[\(f.string(from: timestamp))] \(category): \(message)"
    }
}

/// Singleton log the popover reads. Use `InfoLog.shared.info(...)`.
/// Tests / previews can construct a fresh `InfoLog()` and inject it.
@MainActor
public final class InfoLog: ObservableObject {
    public static let shared = InfoLog()

    /// Latest entries first; capped to keep memory bounded.
    @Published public private(set) var events: [InfoLogEvent] = []

    /// Set to false to silence this category while still keeping os_log elsewhere.
    public var isEnabled: Bool = true

    private let capacity: Int
    private let lock = NSLock()

    public init(capacity: Int = 200) {
        self.capacity = capacity
    }

    public func info(_ message: String, category: String = "info", kind: InfoLogKind = .info) {
        guard isEnabled else { return }
        let event = InfoLogEvent(category: category, message: message, kind: kind)
        // The mutation is cheap; we are already on the MainActor by isolation.
        events.insert(event, at: 0)
        if events.count > capacity {
            events.removeLast(events.count - capacity)
        }
        // objectWillChange is published automatically by @Published.
    }

    public func clear() {
        events.removeAll()
    }

    /// All events rendered as bare log lines, oldest first (natural reading order).
    /// This is what the Copy button puts on the pasteboard.
    public func plainText() -> String {
        events.reversed().map { $0.formatted }.joined(separator: "\n")
    }
}

/// Non-isolated entry points so callers on any thread can log safely.
/// Internally hops to the MainActor before mutating the singleton.
public enum InfoLogCall {
    @MainActor
    private static func _info(_ message: String, category: String, kind: InfoLogKind) {
        InfoLog.shared.info(message, category: category, kind: kind)
    }

    public static func info(_ message: String, category: String = "info", kind: InfoLogKind = .info) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                _info(message, category: category, kind: kind)
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    _info(message, category: category, kind: kind)
                }
            }
        }
    }

    @MainActor
    private static func _clear() { InfoLog.shared.clear() }

    public static func clear() {
        if Thread.isMainThread {
            MainActor.assumeIsolated { _clear() }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { _clear() }
            }
        }
    }
}
