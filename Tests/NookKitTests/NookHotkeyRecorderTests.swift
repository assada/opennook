// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest

@testable import NookKit

@MainActor
final class NookHotkeyRecorderTests: XCTestCase {
    func testOnlyOneRecorderOwnsTheProcessWideSession() {
        let appState = AppState()
        let first = NookHotkeyRecorder(appState: appState)
        let second = NookHotkeyRecorder(appState: appState)

        first.start()
        XCTAssertTrue(first.isRecording)
        XCTAssertTrue(appState.isRecordingHotkey)

        second.start()
        XCTAssertFalse(first.isRecording, "starting another surface ends the old session")
        XCTAssertTrue(second.isRecording)
        XCTAssertTrue(appState.isRecordingHotkey)

        second.stop()
        XCTAssertFalse(appState.isRecordingHotkey)
    }

    func testRecorderDeinitReleasesMonitorAndRestoresGlobalHotkeyState() {
        let appState = AppState()
        weak var weakRecorder: NookHotkeyRecorder?

        do {
            let recorder = NookHotkeyRecorder(appState: appState)
            weakRecorder = recorder
            recorder.start()
            XCTAssertTrue(appState.isRecordingHotkey)
        }

        XCTAssertNil(weakRecorder, "the event monitor must not retain its recorder")
        XCTAssertFalse(appState.isRecordingHotkey, "the RAII lease restores suspension on deinit")
    }
}
