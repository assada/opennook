// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Carbon.HIToolbox
import Combine

/// Shared recording session for the user-configurable global show/hide hotkey.
///
/// Settings and host onboarding flows use this same object so capture, cancellation,
/// persistence, and live hotkey suspension cannot drift between surfaces.
@MainActor
public final class NookHotkeyRecorder: ObservableObject {
    @Published public private(set) var isRecording = false

    private weak var appState: AppState?
    private var eventMonitor: Any?

    public init(appState: AppState) {
        self.appState = appState
    }

    public func toggle() {
        isRecording ? stop() : start()
    }

    public func start() {
        guard !isRecording, appState != nil else { return }

        isRecording = true
        appState?.isRecordingHotkey = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    public func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil

        guard isRecording else { return }
        isRecording = false
        appState?.isRecordingHotkey = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        if event.keyCode == UInt16(kVK_Escape) {
            stop()
            return nil
        }

        guard let hotkey = NookHotkey(event: event) else {
            // Swallow partial or unsupported combinations while the recorder is active.
            return nil
        }

        appState?.replaceHotkey(hotkey)
        stop()
        return nil
    }
}
