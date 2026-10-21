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
/// Callers MUST use `scheduleWriteConfig { ... }` instead of writing
/// the file directly; `flushAll()` is called from
/// `applicationWillTerminate` so a normal quit does not lose pending writes.
final class ConfigDebouncer {
    static let shared = ConfigDebouncer()

    /// Quiescence interval — last scheduled write must be this old before
    /// the disk is touched. 0.5 s matches a UI-affordance; long enough that
    /// a toggle-and-flip sequence produces one write, short enough to
    /// survive any normal pause in interaction.
    private let delay: TimeInterval = 0.5

    /// Pending writes, keyed by token so concurrent callers can register
    /// independently and still coalesce into one disk pass.
    private var pending: [UUID: () -> Void] = [:]
    private var workItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.dailypic.configdebouncer", qos: .utility)

    /// Schedule a write. Resets the debounce window so back-to-back
    /// callers share one disk pass.
    func scheduleWriteConfig(_ write: @escaping () -> Void) {
        queue.async { [weak self] in
            self?._schedule(write)
        }
    }

    private func _schedule(_ write: @escaping () -> Void) {
        let token = UUID()
        pending[token] = write
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.flushAll()
        }
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Flush all pending writes immediately. Called from
    /// `applicationWillTerminate` so a normal quit does not drop the
    /// unsaved tail of a toggle sequence.
    func flushAll() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.pending.isEmpty else { return }
            let writes = self.pending.values
            self.pending.removeAll()
            self.workItem?.cancel()
            self.workItem = nil
            for write in writes { write() }
        }
    }
}
