//
//  RuntimeLog.swift
//  Daily Pic
//
//  Created by Paul Zenker on 10.09.26.
//

import Foundation

/// Append-only logger used to correlate background events with future crashes.
/// Writes one line per call to ~/Library/Logs/DailyPic/runtime.log so the
/// signal-9 reports have a trace
enum RuntimeLog {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DailyPic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("runtime.log")
    }()

    private static let queue = DispatchQueue(label: "com.dailypic.runtimelog")

    static func write(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let handle = try? FileHandle(forWritingTo: url) {
                        defer { try? handle.close() }
                        try? handle.seekToEnd()
                        try? handle.write(contentsOf: data)
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    /// Sample current resident memory size (RSS) and append a `rss=` line.
    /// Used to correlate background work with future SIGKILLs.
    static func sampleMemory(tag: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let rssBytes = info.resident_size
            let mb = Double(rssBytes) / 1024.0 / 1024.0
            write("rss=\(String(format: "%.1f", mb)) MB tag=\(tag)")
        }
    }

    /// Start a lightweight sampler that writes RSS every <interval> seconds.
    /// Holds a single shared Task so callers don't pile up timers.
    private static var samplerTask: Task<Void, Never>?
    static func startMemorySampler(interval: TimeInterval = 60) {
        samplerTask?.cancel()
        samplerTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                sampleMemory(tag: "periodic")
                _ = try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// A function that evicts idle cached bitmaps on the active gallery VM.
    /// Provided by the app on launch so the periodic sampler can run it on the
    /// MainActor without this utility knowing about the concrete gallery type.
    typealias Evictor = @MainActor () -> Void
    private static var evictor: Evictor?

    /// Register a callback the periodic sampler should invoke every minute.
    /// Use this to drop idle NSImage caches on the gallery view model.
    static func registerEvictor(_ callback: @escaping Evictor) {
        evictor = callback
    }

    private static var evictorTask: Task<Void, Never>?
    /// Start a periodic idle-bitmap evictor. The registered callback is run
    /// on the MainActor every <interval> seconds so cached NSImages that
    /// have not been touched in a while are freed.
    static func startEvictor(interval: TimeInterval = 60) {
        evictorTask?.cancel()
        evictorTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                _ = try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }
                if let evictor {
                    await MainActor.run { evictor() }
                }
            }
        }
    }
}
