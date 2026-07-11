// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import XCTest

@testable import NookKit

final class SettingsViewportSizingTests: XCTestCase {
    func testShortTargetDisplayIsNotForcedToLegacyMinimumHeight() {
        XCTAssertEqual(
            SettingsViewportSizing.maximumHeight(targetScreenVisibleHeight: 600),
            216,
            accuracy: 0.001
        )
    }

    func testTallTargetDisplayRemainsCappedAtPreferredMaximum() {
        XCTAssertEqual(
            SettingsViewportSizing.maximumHeight(targetScreenVisibleHeight: 2_000),
            440
        )
    }

    func testInvalidTargetGeometryUsesFallback() {
        XCTAssertEqual(
            SettingsViewportSizing.maximumHeight(targetScreenVisibleHeight: 0),
            SettingsViewportSizing.fallbackMaximumHeight
        )
    }
}
