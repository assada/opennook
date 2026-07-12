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

    private func makeNook(layoutGraceDuration: TimeInterval = 0) -> Nook<Text, Text, EmptyView> {
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
            layoutGraceDuration: layoutGraceDuration
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

    func testReadyMeasurementsEvaluateTheEventSnapshotImmediately() {
        var admission = NookCompactHoverAdmission()
        _ = admission.active(
            at: CGPoint(x: 620, y: 17),
            measurementsReady: false
        )
        let eventPoint = CGPoint(x: 640, y: 17)

        XCTAssertEqual(
            admission.active(at: eventPoint, measurementsReady: true),
            eventPoint
        )
        XCTAssertNil(admission.pendingActivePoint)
    }

    func testDisabledOrMeasuredSlotsMakeGeometryReady() {
        XCTAssertFalse(
            NookCompactHoverAdmission.measurementsReady(
                leadingSlotDisabled: false,
                leadingSlotMeasured: true,
                trailingSlotDisabled: false,
                trailingSlotMeasured: false
            )
        )
        XCTAssertTrue(
            NookCompactHoverAdmission.measurementsReady(
                leadingSlotDisabled: false,
                leadingSlotMeasured: true,
                trailingSlotDisabled: true,
                trailingSlotMeasured: false
            )
        )
        XCTAssertTrue(
            NookCompactHoverAdmission.measurementsReady(
                leadingSlotDisabled: false,
                leadingSlotMeasured: true,
                trailingSlotDisabled: false,
                trailingSlotMeasured: true
            )
        )
    }

    func testLatestEventWaitsForFirstMeasurementReadiness() {
        var admission = NookCompactHoverAdmission()
        let firstPoint = CGPoint(x: 620, y: 17)
        let latestPoint = CGPoint(x: 700, y: 17)

        XCTAssertNil(admission.active(at: firstPoint, measurementsReady: false))
        XCTAssertNil(admission.active(at: latestPoint, measurementsReady: false))
        XCTAssertEqual(
            admission.measurementsChanged(from: false, to: true),
            latestPoint,
            "reconciliation must use the latest real HoverPhase event snapshot"
        )
        XCTAssertNil(admission.pendingActivePoint)
    }

    func testReadinessChangesCannotReplayOrSynthesizeHoverAdmissionTwice() {
        var admission = NookCompactHoverAdmission()
        let eventPoint = CGPoint(x: 640, y: 17)

        XCTAssertNil(admission.active(at: eventPoint, measurementsReady: false))
        XCTAssertNil(
            admission.measurementsChanged(from: false, to: false),
            "an incomplete measurement update must preserve the pending event"
        )
        XCTAssertEqual(admission.measurementsChanged(from: false, to: true), eventPoint)
        XCTAssertNil(
            admission.measurementsChanged(from: true, to: true),
            "an update after readiness must not replay or create hover activity"
        )
        XCTAssertNil(admission.measurementsChanged(from: true, to: false))
        XCTAssertNil(admission.measurementsChanged(from: false, to: true))
    }

    func testEndedHoverClearsDeferredEvent() {
        var admission = NookCompactHoverAdmission()
        XCTAssertNil(
            admission.active(
                at: CGPoint(x: 640, y: 17),
                measurementsReady: false
            )
        )

        admission.ended()

        XCTAssertNil(admission.pendingActivePoint)
        XCTAssertNil(admission.measurementsChanged(from: false, to: true))
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

    func testHoverExitDuringLayoutGraceStillCompactsAfterGraceExpires() async throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main display attached")
        }

        let nook = makeNook(layoutGraceDuration: 0.2)
        await nook.expand(on: screen)
        nook.updateHoverState(true)
        await Task.yield()

        // Expanded content resized -> grace opens, then the pointer leaves inside it.
        nook.noteExpandedContentSizeChange()
        XCTAssertTrue(nook.isLayoutGraceActive)
        nook.updateHoverState(false)

        XCTAssertFalse(nook.isHovering)
        XCTAssertEqual(nook.state, .expanded, "grace must defer the exit, not act on it")

        // No further pointer events arrive: the pointer already left. Once grace
        // expires the surface must complete the deferred collapse on its own.
        await waitUntil { nook.state == .compact }

        await nook.hide()
    }

    func testReenterDuringGraceCancelsDeferredExit() async throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main display attached")
        }

        let nook = makeNook(layoutGraceDuration: 0.2)
        await nook.expand(on: screen)
        nook.updateHoverState(true)
        await Task.yield()

        nook.noteExpandedContentSizeChange()
        nook.updateHoverState(false)
        nook.updateHoverState(true)

        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(
            nook.state, .expanded,
            "a re-enter during grace must cancel the deferred exit"
        )

        await nook.hide()
    }

    func testStayExpandedExitDuringGraceIsNotReplayed() async throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main display attached")
        }

        let nook = makeNook(layoutGraceDuration: 0.2)
        nook.staysExpandedOnHoverExit = true
        await nook.expand(on: screen)
        nook.updateHoverState(true)
        await Task.yield()

        nook.noteExpandedContentSizeChange()
        nook.updateHoverState(false)

        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(
            nook.state, .expanded,
            "a stay-expanded exit is swallowed by design and must not replay at expiry"
        )

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
