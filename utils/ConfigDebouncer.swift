//
//  ConfigDebouncer.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.10.26.
//

import Foundation

/// Coalesce repeated `writeConfig()` calls into a single disk write
/// ~500 ms after the last mutation. Protects user prefs from being
/// partially written when the process is SIGKILLed mid-toggle.
///
/// Callers MUST use `scheduleWriteConfig(key:write:)` instead of writing
/// the file directly; `flushAll()` is called from
/// `applicationWillTerminate` so a normal quit does not lose pending writes.
final class ConfigDebouncer {
    static let shared = ConfigDebouncer()

    /// Quiescence interval — last scheduled write must be this old before
    /// the disk is touched. 0.5 s matches a UI-affordance; long enough that
    /// a toggle-and-flip sequence produces one write, short enough to
    /// survive any normal pause in interaction.
    private let delay: TimeInterval = 0.5

    /// Pending writes, keyed by the file they target. A newer write for the
    /// same key replaces the older one, so a burst of toggles collapses into
    /// a single disk pass that persists the *newest* state. Keying by a
    /// fresh UUID per call instead would keep every intermediate snapshot and
    /// let them run in arbitrary order — the oldest snapshot could land last
    /// and silently undo the user's most recent change.
    private var pending: [String: () -> Void] = [:]
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()
    private let timerQueue = DispatchQueue(label: "com.dailypic.configdebouncer", qos: .utility)

    /// Schedule a write for `key`. Resets the debounce window so back-to-back
    /// callers share one disk pass.
    func scheduleWriteConfig(key: String, _ write: @escaping () -> Void) {
        lock.lock()
        pending[key] = write
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.flushAll()
        }
        workItem = item
        lock.unlock()

        timerQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Writes every pending change to disk and returns only once the writes
    /// have completed.
    ///
    /// This is deliberately synchronous. `applicationWillTerminate` calls it
    /// while the process is already on its way out, so an async flush could
    /// be dropped on the floor and the last change (a favourite, a toggle)
    /// would be lost. The pending set is drained under the lock before any
    /// I/O happens, so two concurrent flushes can never write the same file
    /// twice or interleave.
    func flushAll() {
        lock.lock()
        let writes = pending
        pending.removeAll()
        workItem?.cancel()
        workItem = nil
        lock.unlock()

        for write in writes.values {
            write()
        }
    }
}
