// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest

@testable import NookKit

final class AppStateTests: XCTestCase {
    func testViewModeHelpersKeepHomeAndSettingsExclusive() {
        let state = AppState()

        XCTAssertTrue(state.isHomeView)
        XCTAssertFalse(state.isSettingsView)

        state.showSettings()
        XCTAssertEqual(state.viewMode, .settings)
        XCTAssertFalse(state.isHomeView)
        XCTAssertTrue(state.isSettingsView)

        state.showHome()
        XCTAssertEqual(state.viewMode, .home)
        XCTAssertTrue(state.isHomeView)
        XCTAssertFalse(state.isSettingsView)
    }

    func testNavigateBackClearsModuleBreadcrumbFromHome() {
        let state = AppState()
        state.moduleBreadcrumb = "Summary"

        XCTAssertTrue(state.canNavigateBack)
        XCTAssertTrue(state.navigateBack())
        XCTAssertNil(state.moduleBreadcrumb)
        XCTAssertFalse(state.canNavigateBack)
    }

    func testNavigateBackReturnsFromSettingsBeforeClearingBreadcrumb() {
        let state = AppState()
        state.moduleBreadcrumb = "Summary"
        state.showSettings()

        XCTAssertTrue(state.navigateBack())
        XCTAssertTrue(state.isHomeView)
        XCTAssertEqual(state.moduleBreadcrumb, "Summary")

        XCTAssertTrue(state.navigateBack())
        XCTAssertNil(state.moduleBreadcrumb)
    }

    func testNavigateBackIsNoOpAtRootHome() {
        let state = AppState()

        XCTAssertFalse(state.canNavigateBack)
        XCTAssertFalse(state.navigateBack())
        XCTAssertTrue(state.isHomeView)
    }

    func testResetTransientStatusClearsError() {
        let state = AppState()
        state.errorMessage = "Something broke"

        state.resetTransientStatus()

        XCTAssertNil(state.errorMessage)
    }

    // MARK: - Hotkey registration failure state

    /// A recorded hotkey-registration failure is visible on the durable channel.
    func testHotkeyRegistrationFailureIsRecorded() {
        let state = AppState()
        let failure = HotkeyRegistrationFailure(shortcutName: "Show Nook", combination: "⌥⌘;")

        state.recordHotkeyRegistration(id: "toggle", failure: failure)

        XCTAssertEqual(state.hotkeyRegistrationFailures["toggle"], failure)
    }

    func testGlobalHotkeyFailureHasPublicConvenienceAccessor() {
        let state = AppState()
        let failure = HotkeyRegistrationFailure(
            shortcutName: "Show Nook",
            combination: "⌥Space"
        )

        state.recordHotkeyRegistration(id: NookHotkeyIDs.toggle, failure: failure)

        XCTAssertEqual(state.globalHotkeyRegistrationFailure, failure)
    }

    /// A hotkey-registration failure must survive a transient-status reset - unlike
    /// `errorMessage`, it outlives a single nook session.
    func testHotkeyRegistrationFailureSurvivesTransientReset() {
        let state = AppState()
        let failure = HotkeyRegistrationFailure(shortcutName: "Show Nook", combination: "⌥⌘;")
        state.recordHotkeyRegistration(id: "toggle", failure: failure)
        state.errorMessage = "transient"

        state.resetTransientStatus()

        XCTAssertNil(state.errorMessage, "the transient channel is cleared")
        XCTAssertEqual(
            state.hotkeyRegistrationFailures["toggle"],
            failure,
            "the durable hotkey failure is NOT cleared by a transient reset"
        )
    }

    /// A later successful registration clears that id's prior failure.
    func testSuccessfulRegistrationClearsPriorFailure() {
        let state = AppState()
        state.recordHotkeyRegistration(
            id: "toggle",
            failure: HotkeyRegistrationFailure(shortcutName: "Show Nook", combination: "⌥⌘;")
        )
        XCTAssertNotNil(state.hotkeyRegistrationFailures["toggle"])

        // A success records a `nil` failure for the same id.
        state.recordHotkeyRegistration(id: "toggle", failure: nil)

        XCTAssertNil(
            state.hotkeyRegistrationFailures["toggle"],
            "a successful re-registration clears the failure"
        )
    }

    /// Failures are tracked per registration id - one shortcut's failure never
    /// overwrites another's, and clearing one leaves the other intact.
    func testHotkeyRegistrationFailuresAreTrackedPerID() {
        let state = AppState()
        let toggleFailure = HotkeyRegistrationFailure(shortcutName: "Show Nook", combination: "⌥⌘;")
        let moduleFailure = HotkeyRegistrationFailure(shortcutName: "Clock", combination: "⌃⌥C")

        state.recordHotkeyRegistration(id: "toggle", failure: toggleFailure)
        state.recordHotkeyRegistration(id: "module.clock", failure: moduleFailure)

        XCTAssertEqual(state.hotkeyRegistrationFailures["toggle"], toggleFailure)
        XCTAssertEqual(state.hotkeyRegistrationFailures["module.clock"], moduleFailure)

        // Clearing one leaves the other visible.
        state.recordHotkeyRegistration(id: "toggle", failure: nil)
        XCTAssertNil(state.hotkeyRegistrationFailures["toggle"])
        XCTAssertEqual(
            state.hotkeyRegistrationFailures["module.clock"],
            moduleFailure,
            "clearing one shortcut's failure must not touch another's"
        )
    }

    func testHotkeyRebindWithoutCoordinatorFailsClosedAndDoesNotPersist() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            let state = AppState()
            let original = state.hotkey
            let candidate = NookHotkey(
                keyCode: 13,
                carbonModifiers: 2048,
                keySymbol: "W"
            )

            let result = state.requestHotkeyRebind(candidate)

            guard case .rejected = result else {
                return XCTFail("an unattached AppState cannot verify a Carbon registration")
            }
            XCTAssertEqual(state.hotkey, original)
            XCTAssertNil(NookPreferenceStorage.defaults.data(forKey: "opennook.hotkey.v1"))
        }
    }
}
