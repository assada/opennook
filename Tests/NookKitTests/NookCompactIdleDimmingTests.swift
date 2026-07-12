// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI
import XCTest

@testable import NookKit
@testable import NookSurface

@MainActor
final class NookCompactIdleDimmingTests: XCTestCase {
    private final class ActivityCounter: @unchecked Sendable {
        var value = 0
    }

    private func makeDimming(
        delay: Duration = .seconds(4),
        dimmedOpacity: Double = 0.42
    ) -> NookCompactIdleDimming {
        NookCompactIdleDimming(
            delay: delay,
            dimmedOpacity: dimmedOpacity,
            dimAnimation: .linear(duration: 0.2),
            restoreAnimation: .linear(duration: 0.1)
        )
    }

    private func makeCoordinator(surface: FakeNookSurface) -> AppCoordinator {
        var host = NookHostConfiguration()
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) {
            NookConfiguration()
        }
        host.defaultModule = "A"
        return AppCoordinator(
            appState: AppState(),
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(5),
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

    func testIdleDimmingIsDisabledByDefaultAcrossConfigurationPaths() {
        XCTAssertNil(NookChromeBehavior.default.compactIdleDimming)
        XCTAssertNil(NookConfiguration().chromeBehavior.compactIdleDimming)
        XCTAssertNil(NookHostConfiguration().chromeBehavior.compactIdleDimming)
    }

    func testChromeBehaviorInitializerCarriesIdleDimmingConfiguration() {
        let behavior = NookChromeBehavior(compactIdleDimming: makeDimming())

        XCTAssertEqual(behavior.compactIdleDimming?.delay, .seconds(4))
        XCTAssertEqual(behavior.compactIdleDimming?.dimmedOpacity, 0.42)
    }

    func testIdleDimmingConfigurationResolvesHostileValuesSafely() {
        XCTAssertEqual(
            makeDimming(delay: .seconds(-2), dimmedOpacity: -0.4).resolvedDelay,
            .zero
        )
        XCTAssertEqual(makeDimming(dimmedOpacity: -0.4).resolvedDimmedOpacity, 0)
        XCTAssertEqual(makeDimming(dimmedOpacity: 1.4).resolvedDimmedOpacity, 1)
        XCTAssertEqual(makeDimming(dimmedOpacity: .nan).resolvedDimmedOpacity, 1)
        XCTAssertEqual(makeDimming(dimmedOpacity: .infinity).resolvedDimmedOpacity, 1)
    }

    func testHostConfigurationForwardsIdleDimmingToModuleHost() {
        var host = NookHostConfiguration()
        host.chromeBehavior.compactIdleDimming = makeDimming(
            delay: .seconds(7),
            dimmedOpacity: 0.36
        )
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) {
            NookConfiguration()
        }

        let behavior = ModuleHost(registry: host.makeRegistry()).chromeBehavior

        XCTAssertEqual(behavior.compactIdleDimming?.delay, .seconds(7))
        XCTAssertEqual(behavior.compactIdleDimming?.dimmedOpacity, 0.36)
    }

    func testSingleModuleConfigurationForwardsIdleDimmingToModuleHost() {
        var configuration = NookConfiguration()
        configuration.chromeBehavior.compactIdleDimming = makeDimming(
            delay: .seconds(3),
            dimmedOpacity: 0.58
        )

        let behavior = ModuleHost(configuration: configuration).chromeBehavior

        XCTAssertEqual(behavior.compactIdleDimming?.delay, .seconds(3))
        XCTAssertEqual(behavior.compactIdleDimming?.dimmedOpacity, 0.58)
    }

    func testCoordinatorFactoryPassesIdleDimmingToConcreteSurface() {
        var configuration = NookConfiguration()
        configuration.chromeBehavior.compactIdleDimming = makeDimming(
            delay: .seconds(6),
            dimmedOpacity: 0.47
        )
        let moduleHost = ModuleHost(configuration: configuration)

        let nook = AppCoordinator.makeDefaultNook(
            moduleHost: moduleHost,
            appState: AppState(),
            coordinatorBox: AppCoordinator.CoordinatorBox()
        )

        XCTAssertEqual(nook.compactIdleDimming?.delay, .seconds(6))
        XCTAssertEqual(nook.compactIdleDimming?.dimmedOpacity, 0.47)
    }

    func testCoordinatorForwardsEveryExplicitCompactActivity() {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.noteCompactActivity()
        coordinator.noteCompactActivity()

        XCTAssertEqual(surface.compactActivityCount, 2)
    }

    func testEnvironmentActionForwardsExplicitCompactActivity() {
        let counter = ActivityCounter()
        let action = NookCompactActivityAction {
            counter.value += 1
        }

        action()

        XCTAssertEqual(counter.value, 1)
    }

    func testCompactModuleSwitchReportsActivity() async {
        var host = NookHostConfiguration()
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) {
            NookConfiguration()
        }
        host.register(NookModuleDescriptor(id: "B", displayName: "B")) {
            NookConfiguration()
        }
        host.defaultModule = "A"
        let surface = FakeNookSurface()
        let coordinator = AppCoordinator(
            appState: AppState(),
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )
        await surface.compact(on: nil)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.compactActivityCount, 1)
    }

    func testLowLevelActivityDoesNotChangeLifecycleWhenDimmingIsDisabled() {
        let nook = Nook(expanded: { Text("expanded") })

        nook.noteCompactActivity()

        XCTAssertEqual(nook.state, .hidden)
        XCTAssertFalse(nook.hasLiveWindow)
    }

    func testDisabledDimmingDoesNotArmCompactDeadline() {
        let nook = Nook(expanded: { Text("expanded") })

        nook.handleCompactIdleDimmingStateChange(to: .compact)
        nook.noteCompactActivity()

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNil(nook.compactIdleDimmingDeadline)
        XCTAssertNil(nook.compactIdleDimmingTask)
    }

    func testEnteringAndLeavingCompactOwnsExactlyOneIdleCycle() {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .seconds(60)),
            expanded: { Text("expanded") }
        )

        nook.handleCompactIdleDimmingStateChange(to: .compact)

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNotNil(nook.compactIdleDimmingDeadline)
        XCTAssertNotNil(nook.compactIdleDimmingTask)

        nook.handleCompactIdleDimmingStateChange(to: .expanded)

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNil(nook.compactIdleDimmingDeadline)
        XCTAssertNil(nook.compactIdleDimmingTask)
    }

    func testExplicitActivityRestoresDimmedContentAndRearmsDeadline() async {
        let nook = Nook(
            compactIdleDimming: makeDimming(
                delay: .milliseconds(10),
                dimmedOpacity: 0.4
            ),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        await waitUntil { nook.compactContentOpacity == 0.4 }

        XCTAssertNil(nook.compactIdleDimmingDeadline)
        XCTAssertNil(nook.compactIdleDimmingTask)

        nook.noteCompactActivity()

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNotNil(nook.compactIdleDimmingDeadline)
        XCTAssertNotNil(nook.compactIdleDimmingTask)

        nook.handleCompactIdleDimmingStateChange(to: .expanded)
    }

    func testValidHoverRestoresDimmedContentButRejectedHoverDoesNot() async {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .milliseconds(10), dimmedOpacity: 0.4),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        await waitUntil { nook.compactContentOpacity == 0.4 }

        nook.updateHoverState(true, withinInteractionRegion: false)
        XCTAssertEqual(nook.compactContentOpacity, 0.4)
        XCTAssertNil(nook.compactIdleDimmingDeadline)

        nook.updateHoverState(true, withinInteractionRegion: true)
        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNotNil(nook.compactIdleDimmingDeadline)

        nook.handleCompactIdleDimmingStateChange(to: .hidden)
    }

    func testFeedbackRestoresDimmedContentAndRearmsDeadline() async {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .milliseconds(10), dimmedOpacity: 0.4),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        await waitUntil { nook.compactContentOpacity == 0.4 }

        nook.playFeedback(.shimmer)

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNotNil(nook.compactIdleDimmingDeadline)

        nook.handleCompactIdleDimmingStateChange(to: .hidden)
    }

    func testFirstDragEntryRestoresDimmedContentAndRearmsDeadline() async {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .milliseconds(10), dimmedOpacity: 0.4),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        await waitUntil { nook.compactContentOpacity == 0.4 }

        _ = nook.nookPanelDraggingEntered([])

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertNotNil(nook.compactIdleDimmingDeadline)

        nook.handleCompactIdleDimmingStateChange(to: .hidden)
    }

    func testCancelledWorkerCannotMutateANewerCompactCycle() async throws {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .seconds(60), dimmedOpacity: 0.4),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        let firstWorker = try XCTUnwrap(nook.compactIdleDimmingTask)

        nook.handleCompactIdleDimmingStateChange(to: .expanded)
        XCTAssertTrue(firstWorker.isCancelled)

        nook.handleCompactIdleDimmingStateChange(to: .compact)
        let secondDeadline = try XCTUnwrap(nook.compactIdleDimmingDeadline)
        let secondWorker = try XCTUnwrap(nook.compactIdleDimmingTask)
        await firstWorker.value

        XCTAssertEqual(nook.compactContentOpacity, 1)
        XCTAssertEqual(nook.compactIdleDimmingDeadline, secondDeadline)
        XCTAssertNotNil(nook.compactIdleDimmingTask)
        XCTAssertFalse(secondWorker.isCancelled)

        nook.handleCompactIdleDimmingStateChange(to: .hidden)
    }

    func testActivityMovesTheExistingDeadlineForward() async throws {
        let nook = Nook(
            compactIdleDimming: makeDimming(delay: .seconds(60)),
            expanded: { Text("expanded") }
        )
        nook.handleCompactIdleDimmingStateChange(to: .compact)
        let firstDeadline = try XCTUnwrap(nook.compactIdleDimmingDeadline)

        try? await Task.sleep(for: .milliseconds(1))
        nook.noteCompactActivity()
        let movedDeadline = try XCTUnwrap(nook.compactIdleDimmingDeadline)

        XCTAssertGreaterThan(movedDeadline, firstDeadline)
        XCTAssertNotNil(nook.compactIdleDimmingTask)

        nook.handleCompactIdleDimmingStateChange(to: .hidden)
    }
}
