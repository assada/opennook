// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest

@testable import NookKit
@testable import NookSurface

@MainActor
final class NookUnattendedExpansionTests: XCTestCase {
    private func makeCoordinator(surface: FakeNookSurface) -> AppCoordinator {
        var host = NookHostConfiguration()
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) {
            NookConfiguration()
        }
        host.defaultModule = "A"
        let appState = AppState()
        // These tests exercise presentation policy, not persistence. Reset the in-memory
        // value explicitly so parallel workers cannot inherit another test's saved
        // keep-open preference from the shared standard defaults domain.
        appState.appearancePreferences = .default
        return AppCoordinator(
            appState: appState,
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )
    }

    /// Joins the current lifecycle tail, gives zero-duration deadline workers a turn,
    /// then joins any transition they enqueued. No wall-clock timing window involved.
    private func drainLifecycleAndDeadlines(_ coordinator: AppCoordinator) async {
        await coordinator.drainLifecycleForTesting()
        for _ in 0..<8 {
            await Task.yield()
            await coordinator.drainLifecycleForTesting()
        }
    }

    func testBehaviorDefaultsAndResolvesHostileTimeout() {
        XCTAssertNil(NookExpansionBehavior.userInitiated.unattendedTimeout)
        XCTAssertEqual(
            NookExpansionBehavior.unattended(timeout: .seconds(-2)).unattendedTimeout,
            .zero
        )
        XCTAssertEqual(
            NookExpansionBehavior.unattended(timeout: .seconds(8)).unattendedTimeout,
            .seconds(8)
        )
    }

    func testControllerReusesMovableDeadlineWorkerAndCancelsIt() {
        let controller = NookUnattendedExpansionController()
        controller.arm(after: .seconds(60)) {}
        let firstWorker = controller.workerTask
        let firstDeadline = controller.deadline

        controller.arm(after: .seconds(120)) {}

        XCTAssertTrue(controller.isArmed)
        XCTAssertNotNil(controller.workerTask)
        XCTAssertFalse(firstWorker?.isCancelled ?? true, "re-arm keeps the existing worker alive")
        guard let refreshedDeadline = controller.deadline, let firstDeadline else {
            XCTFail("both deadlines must be present while the controller is armed")
            return
        }
        XCTAssertGreaterThan(refreshedDeadline, firstDeadline)

        controller.cancel()

        XCTAssertFalse(controller.isArmed)
        XCTAssertNil(controller.deadline)
        XCTAssertNil(controller.workerTask)
        XCTAssertTrue(firstWorker?.isCancelled ?? false)
    }

    func testZeroDeadlineFiresOnceAndReturnsControllerToIdle() async {
        let controller = NookUnattendedExpansionController()
        var fireCount = 0

        controller.arm(after: .zero) { fireCount += 1 }
        for _ in 0..<8 where fireCount == 0 {
            await Task.yield()
        }

        XCTAssertEqual(fireCount, 1)
        XCTAssertFalse(controller.isArmed)
        XCTAssertNil(controller.workerTask)

        for _ in 0..<4 { await Task.yield() }
        XCTAssertEqual(fireCount, 1, "the completed worker cannot fire twice")
    }

    func testUserInitiatedShowRemainsExpandedWithoutDeadline() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook()
        await drainLifecycleAndDeadlines(coordinator)

        XCTAssertEqual(surface.state, .expanded)
        XCTAssertTrue(coordinator.isUserEngaged)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }

    func testDefaultHotkeyToggleRemainsUserInitiated() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.toggleNook()
        await drainLifecycleAndDeadlines(coordinator)

        XCTAssertEqual(surface.state, .expanded)
        XCTAssertTrue(coordinator.isUserEngaged)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }

    func testCustomPeekToggleCanOptIntoUnattendedDeadline() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.toggleNook(presentation: .unattended(timeout: .zero))
        await drainLifecycleAndDeadlines(coordinator)

        XCTAssertEqual(surface.transitions, [.expanded, .compact])
        XCTAssertEqual(surface.state, .compact)
    }

    func testUnattendedShowCompactsAtDeadlineWithoutEngagement() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showHome(presentation: .unattended(timeout: .zero))
        await drainLifecycleAndDeadlines(coordinator)

        XCTAssertEqual(surface.transitions, [.expanded, .compact])
        XCTAssertEqual(surface.state, .compact)
        XCTAssertFalse(coordinator.isUserEngaged)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }

    func testPointerEntryAcknowledgesUnattendedExpansionPermanently() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.unattendedExpansionController.isArmed)

        surface.isHovering = true
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)

        surface.isHovering = false
        for _ in 0..<4 { await Task.yield() }
        XCTAssertEqual(surface.state, .expanded, "leaving does not resurrect the cancelled timer")
    }

    func testDragEntryAcknowledgesUnattendedExpansion() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.unattendedExpansionController.isArmed)

        surface.isDragInFlight = true

        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
        XCTAssertEqual(surface.state, .expanded)
    }

    func testKeepOpenAndPresentationPinCancelUnattendedDeadline() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.unattendedExpansionController.isArmed)

        var preferences = coordinator.appState.appearancePreferences
        preferences.keepNookOpen = true
        coordinator.appState.appearancePreferences = preferences
        coordinator.setKeepNookOpen(true)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)

        preferences.keepNookOpen = false
        coordinator.appState.appearancePreferences = preferences
        coordinator.setKeepNookOpen(false)
        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.unattendedExpansionController.isArmed)

        let pin = coordinator.presentationPinning.pin(reason: "test")
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
        pin.release()
    }

    func testAutomaticResultDoesNotConvertExistingUserSessionIntoTimeout() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook()
        await coordinator.drainLifecycleForTesting()
        coordinator.showHome(presentation: .unattended(timeout: .zero))
        await drainLifecycleAndDeadlines(coordinator)

        XCTAssertEqual(surface.state, .expanded)
        XCTAssertTrue(coordinator.isUserEngaged)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }

    func testExplicitShowTakesOwnershipFromUnattendedCycle() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.unattendedExpansionController.isArmed)

        coordinator.showNook()
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.state, .expanded)
        XCTAssertTrue(coordinator.isUserEngaged)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }

    func testRepeatedUnattendedShowMovesDeadlineWithoutCancellingWorker() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        let firstWorker = coordinator.unattendedExpansionController.workerTask
        let firstDeadline = coordinator.unattendedExpansionController.deadline

        coordinator.showNook(presentation: .unattended(timeout: .seconds(120)))
        await coordinator.drainLifecycleForTesting()

        XCTAssertFalse(firstWorker?.isCancelled ?? true)
        guard let refreshedDeadline = coordinator.unattendedExpansionController.deadline,
            let firstDeadline
        else {
            XCTFail("repeated unattended presentation must keep a live deadline")
            return
        }
        XCTAssertGreaterThan(refreshedDeadline, firstDeadline)
    }

    func testCompactOrDismissCancelsUnattendedDeadline() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(surface: surface)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        coordinator.compactNook()
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.state, .compact)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)

        coordinator.showNook(presentation: .unattended(timeout: .seconds(60)))
        await coordinator.drainLifecycleForTesting()
        coordinator.dismissNook()
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.state, .hidden)
        XCTAssertFalse(coordinator.unattendedExpansionController.isArmed)
    }
}
