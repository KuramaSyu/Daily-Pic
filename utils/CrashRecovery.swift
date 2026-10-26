//
//  CrashRecovery.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.10.26.
//

import Foundation

/// Crash-recovery marker that survives a SIGKILL.
///
/// The marker lives in `Library/Application Support/DailyPic/alive_marker`,
/// a directory the `com.apple.cache_delete` scan never touches (cache_delete
/// reclaims `Library/Caches` only). The marker is refreshed every minute by
/// the RSS memory sampler; `applicationWillTerminate` removes it so a clean
/// quit does not look like a SIGKILL to the next launch.
///
/// On the next launch, if the marker is still present, the previous run
/// was killed without `applicationWillTerminate` firing — i.e. a SIGKILL.
/// The marker payload is `<pid>:<timestamp>`. The pid lets a launch tell a
/// *previous* process from the *current* one: the sampler refreshes the
/// marker moments after launch, so a marker carrying our own pid is our own
/// heartbeat and must never be reported as a crash.
enum CrashRecovery {
    private static let markerURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DailyPic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("alive_marker")
    }()

    private static let queue = DispatchQueue(label: "com.dailypic.crashrecovery", qos: .utility)

    /// Our own pid, stamped into every marker we write.
    private static var processIdentifier: Int32 {
        ProcessInfo.processInfo.processIdentifier
    }

    /// Refresh the marker. Cheap (a single-byte write); called from the
    /// periodic RSS sampler so a graceful run keeps the marker in sync
    /// with its sample times.
    static func touch(now: Date = Date()) {
        let payload = "\(processIdentifier):\(now.timeIntervalSince1970)"
        let url = markerURL
        queue.async {
            try? payload.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Parse a marker payload into its pid and timestamp.
    private static func parse(_ raw: String) -> (pid: Int32, date: Date)? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let pid = Int32(parts[0]),
              let interval = TimeInterval(parts[1]) else { return nil }
        return (pid, Date(timeIntervalSince1970: interval))
    }

    /// Read the previous instance's last marker timestamp.
    /// Returns nil if there is no marker (fresh install or first run).
    /// Does NOT mutate the marker; intended for diagnostics that don't
    /// want to interfere with the running sampler.
    static func inspectPrevious() -> Date? {
        guard let raw = try? String(contentsOf: markerURL, encoding: .utf8),
              let parsed = parse(raw) else { return nil }
        return parsed.date
    }

    /// Read and remove the leftover marker, reporting when the previous run
    /// died without `applicationWillTerminate` (i.e. SIGKILL or a crash).
    ///
    /// No freshness window is applied on purpose: `markCleanShutdown()` runs
    /// on every graceful exit, so ANY marker found at launch means the
    /// previous run ended abnormally. A freshness guard would hide exactly
    /// the case we care about most -- macOS relaunching the app within a
    /// minute of killing it.
    ///
    /// Call this from launch BEFORE `RuntimeLog.startMemorySampler` fires its
    /// first iteration, so the sampler's first `touch()` cannot clobber the
    /// evidence.
    @discardableResult
    static func consumeStaleMarker() -> (stamped: Date, age: TimeInterval)? {
        guard let raw = try? String(contentsOf: markerURL, encoding: .utf8) else { return nil }
        // Drop the marker either way: a leftover from this process is just our
        // own heartbeat, and one from a dead process has served its purpose
        // now that we have read it.
        try? FileManager.default.removeItem(at: markerURL)
        guard let parsed = parse(raw) else { return nil }
        // A marker written by the *current* process is our own heartbeat, not
        // evidence of a crash. The RSS sampler refreshes the marker every
        // minute, and this function can run after that first refresh, so
        // without the pid check every launch reported a bogus
        // "previous instance SIGKILLed (died 0s ago)" — and consuming the
        // marker also destroyed the evidence for a real crash in the first
        // minute after launch.
        guard parsed.pid != processIdentifier else { return nil }
        let age = Date().timeIntervalSince(parsed.date)
        return (parsed.date, age)
    }

    /// Drop the marker. Called from `applicationWillTerminate` so a normal
    /// quit doesn't get mis-attributed to a SIGKILL next launch.
    static func markCleanShutdown() {
        try? FileManager.default.removeItem(at: markerURL)
    }
}
