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
    /// Inline, recoverable feedback for the latest rejected key combination. Cleared
    /// when a new recording session starts or a candidate succeeds.
    @Published public private(set) var feedbackMessage: String?

    private static weak var activeRecorder: NookHotkeyRecorder?
    private weak var appState: AppState?
    private var recordingLease: NookHotkeyRecordingLease?

    public init(appState: AppState) {
        self.appState = appState
    }

    public func toggle() {
        isRecording ? stop() : start()
    }

    public func start() {
        guard !isRecording, appState != nil else { return }

        // A host can expose the public recorder in onboarding as well as Settings.
        // Only one process-wide monitor may own capture and suspension at a time.
        Self.activeRecorder?.stop()
        Self.activeRecorder = self
        feedbackMessage = nil
        isRecording = true
        guard let appState else { return }
        appState.isRecordingHotkey = true
        guard
            let monitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown,
                handler: { [weak self] event in
                    self?.handle(event) ?? event
                }
            )
        else {
            isRecording = false
            Self.activeRecorder = nil
            appState.isRecordingHotkey = false
            feedbackMessage = "Shortcut recording is unavailable. Try again."
            return
        }
        recordingLease = NookHotkeyRecordingLease(monitor: monitor, appState: appState)
    }

    public func stop() {
        let ownsActiveSession = Self.activeRecorder === self
        recordingLease?.invalidate()
        recordingLease = nil
        feedbackMessage = nil

        guard isRecording else { return }
        isRecording = false
        if ownsActiveSession {
            Self.activeRecorder = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        if event.keyCode == UInt16(kVK_Escape) {
            stop()
            return nil
        }

        guard let hotkey = NookHotkey(event: event) else {
            feedbackMessage = "Use Command, Option, or Control with a supported key."
            return nil
        }

        if let rejection = NookHotkeyValidation.rejectionMessage(for: hotkey) {
            feedbackMessage = rejection
            return nil
        }

        switch appState?.requestHotkeyRebind(hotkey) {
            case .accepted:
                feedbackMessage = nil
                stop()
            case .rejected(let message):
                feedbackMessage = message
            case nil:
                feedbackMessage = "The shortcut service is unavailable. Try again."
        }
        return nil
    }
}
