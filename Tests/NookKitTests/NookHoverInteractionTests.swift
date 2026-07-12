// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import AppKit
import SwiftUI
import XCTest

@testable import NookSurface

@MainActor
final class NookHoverInteractionTests: XCTestCase {

    private func makeNook() -> Nook<Text, Text, EmptyView> {
        let nook = Nook(
            hoverBehavior: [],
            expanded: { Text("expanded") },
            compactLeading: { Text("compact") }
        )
        nook.transitionConfiguration = NookTransitionConfiguration(
            openingAnimation: .linear(duration: 0),
            closingAnimation: .linear(duration: 0),
            conversionAnimation: .linear(duration: 0.12),
            skipIntermediateHides: true,
            animationDuration: 0.12,
            layoutGraceDuration: 0
        )
        return nook
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        pollInterval: Duration = .milliseconds(10),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: pollInterval)
        }
        XCTFail("condition not met within \(timeout)", file: file, line: line)
    }

    func testNotchTargetRejectsFormerExpandedArea() throws {
        let panelFrame = CGRect(x: -1512, y: 450, width: 1512, height: 450)
        let target = try XCTUnwrap(
            NookCompactHoverTarget(
                panelFrame: panelFrame,
                form: .notch,
                notchSize: CGSize(width: 180, height: 34),
                menubarHeight: 34,
                leadingWidth: 40,
                trailingWidth: 24
            )
        )

        // width = slots + notch gap + two 6 pt ears; asymmetric slots shift left by 8 pt.
        XCTAssertEqual(target.screenFrame, CGRect(x: -892, y: 866, width: 256, height: 34))
        XCTAssertTrue(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.midX, y: target.screenFrame.midY)
            )
        )
        XCTAssertTrue(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.minX + 26, y: target.screenFrame.midY)
            ),
            "the visible leading compact lobe must remain immediately hoverable"
        )
        XCTAssertTrue(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.maxX - 18, y: target.screenFrame.midY)
            ),
            "the visible trailing compact lobe must remain immediately hoverable"
        )
        XCTAssertFalse(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.midX, y: target.screenFrame.minY - 80)
            ),
            "the vacated expanded footprint must not remain hoverable"
        )

        // Still inside the bounding rect, but outside the visible curved bottom corner.
        XCTAssertFalse(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.minX + 1, y: target.screenFrame.minY + 1)
            )
        )
    }

    func testFloatingTargetAccountsForMenuBarInset() throws {
        let target = try XCTUnwrap(
            NookCompactHoverTarget(
                panelFrame: CGRect(x: 100, y: 500, width: 1200, height: 400),
                form: .floating,
                notchSize: CGSize(width: 180, height: 32),
                menubarHeight: 25,
                leadingWidth: 30,
                trailingWidth: 20
            )
        )

        // Floating uses an 8 pt center gap, 16 pt capsule radii, and a 33 pt top inset.
        XCTAssertEqual(target.screenFrame, CGRect(x: 655, y: 835, width: 90, height: 32))
        XCTAssertTrue(
            target.contains(
                screenPoint: CGPoint(x: target.screenFrame.midX, y: target.screenFrame.midY)
            )
        )
    }

    func testInvalidGeometryFailsClosed() {
        XCTAssertNil(
            NookCompactHoverTarget(
                panelFrame: CGRect(x: 0, y: 0, width: 0, height: 400),
                form: .notch,
                notchSize: CGSize(width: 180, height: 32),
                menubarHeight: 25,
                leadingWidth: 30,
                trailingWidth: 20
            )
        )
    }

    func testTargetWaitsForEnabledSlotMeasurements() {
        let panelFrame = CGRect(x: 0, y: 500, width: 1200, height: 400)
        let notchSize = CGSize(width: 180, height: 32)

        XCTAssertNil(
            NookCompactHoverTarget(
                panelFrame: panelFrame,
                form: .notch,
                notchSize: notchSize,
                menubarHeight: 25,
                leadingWidth: nil,
                trailingWidth: 20
            ),
            "an enabled but unmeasured slot must fail closed"
        )
        XCTAssertNotNil(
            NookCompactHoverTarget(
                panelFrame: panelFrame,
                form: .notch,
                notchSize: notchSize,
                menubarHeight: 25,
                leadingWidth: 0,
                trailingWidth: 20
            ),
            "a measured zero-width slot is valid geometry"
        )
        XCTAssertNotNil(
            NookCompactHoverTarget(
                panelFrame: panelFrame,
                form: .notch,
                notchSize: notchSize,
                menubarHeight: 25,
                leadingWidth: nil,
                trailingWidth: 20,
                leadingSlotDisabled: true
            ),
            "a deliberately disabled slot does not require measurement"
        )
    }

    func testGhostEnterDoesNotSupersedeInFlightCollapse() async throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main display attached")
        }

        let nook = makeNook()
        await nook.expand(on: screen)
        nook.updateHoverState(true)
        await Task.yield()

        var expandCount = 0
        nook.onExpand = { expandCount += 1 }

        nook.updateHoverState(false)
        await waitUntil { nook.state == .compact }

        // The animated presentation can still report active here, but the pointer is
        // outside the final compact target. It must not mutate hover or claim a transition.
        nook.updateHoverState(true, withinInteractionRegion: false)
        XCTAssertFalse(nook.isHovering)

        try? await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(nook.state, .compact)
        XCTAssertEqual(expandCount, 0)

        await nook.hide()
    }

    func testValidCompactEnterStillReversesCollapse() async throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main display attached")
        }

        let nook = makeNook()
        await nook.expand(on: screen)
        nook.updateHoverState(true)
        await Task.yield()

        var expandCount = 0
        nook.onExpand = { expandCount += 1 }

        nook.updateHoverState(false)
        await waitUntil { nook.state == .compact }
        nook.updateHoverState(true, withinInteractionRegion: true)

        await waitUntil { nook.state == .expanded }
        XCTAssertTrue(nook.isHovering)
        XCTAssertEqual(expandCount, 1, "a real enter over compact chrome must remain reversible")

        nook.updateHoverState(false)
        await waitUntil { nook.state == .compact }
        await nook.hide()
    }
}
