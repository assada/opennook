// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Foundation

/// Owns one local event monitor and the matching AppState suspension flag. The lease is
/// deliberately Sendable-by-synchronization so its `deinit` can clean up resources even
/// though `NookHotkeyRecorder` has a nonisolated deinitializer under strict concurrency.
final class NookHotkeyRecordingLease: @unchecked Sendable {
    private final class MonitorToken: @unchecked Sendable {
        let value: Any

        init(_ value: Any) {
            self.value = value
        }
    }

    private final class WeakAppState: @unchecked Sendable {
        weak var value: AppState?

        init(_ value: AppState) {
            self.value = value
        }
    }

    private let lock = NSLock()
    private let monitor: MonitorToken
    private let appState: WeakAppState
    private var isInvalidated = false

    init(monitor: Any, appState: AppState) {
        self.monitor = MonitorToken(monitor)
        self.appState = WeakAppState(appState)
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        lock.lock()
        guard !isInvalidated else {
            lock.unlock()
            return
        }
        isInvalidated = true
        lock.unlock()

        let monitor = monitor
        let appState = appState
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                NSEvent.removeMonitor(monitor.value)
                appState.value?.isRecordingHotkey = false
            }
        } else {
            DispatchQueue.main.async {
                NSEvent.removeMonitor(monitor.value)
                appState.value?.isRecordingHotkey = false
            }
        }
    }
}
