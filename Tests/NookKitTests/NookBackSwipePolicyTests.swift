// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import XCTest

@testable import NookSurface

final class NookBackSwipePolicyTests: XCTestCase {
    func testHorizontalMovementMustDominateVerticalScroll() {
        XCTAssertTrue(NookBackSwipePolicy.isHorizontal(deltaX: -8, deltaY: 2))
        XCTAssertFalse(NookBackSwipePolicy.isHorizontal(deltaX: -2, deltaY: 8))
        XCTAssertFalse(NookBackSwipePolicy.isHorizontal(deltaX: 0, deltaY: 0))
    }

    func testOnlyThresholdedBackwardGestureNavigates() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 1,
                phase: .ended,
                isComplete: true,
                isDirectionInvertedFromDevice: true
            )
        )
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0,
                phase: .ended,
                isComplete: true,
                isDirectionInvertedFromDevice: true
            )
        )
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 1,
                phase: .changed,
                isComplete: false,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testPhysicalGestureEndNavigatesBeforeSettlingCompletes() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0.7,
                phase: .ended,
                isComplete: false,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testSettlingCompletionRemainsAFastFlickFallback() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 1,
                phase: [],
                isComplete: true,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testFluidBackDirectionRespectsScrollDirectionPreference() {
        XCTAssertTrue(
            NookBackSwipePolicy.isFluidBackSwipe(
                deltaX: 8,
                deltaY: 2,
                isDirectionInvertedFromDevice: true
            )
        )
        XCTAssertTrue(
            NookBackSwipePolicy.isFluidBackSwipe(
                deltaX: -8,
                deltaY: 2,
                isDirectionInvertedFromDevice: false
            )
        )
        XCTAssertFalse(
            NookBackSwipePolicy.isFluidBackSwipe(
                deltaX: 8,
                deltaY: 2,
                isDirectionInvertedFromDevice: false
            )
        )
    }

    func testGestureBoundsFollowScrollDirectionPreference() {
        XCTAssertEqual(
            NookBackSwipePolicy.minimumGestureAmount(isDirectionInvertedFromDevice: true),
            0
        )
        XCTAssertEqual(
            NookBackSwipePolicy.maximumGestureAmount(isDirectionInvertedFromDevice: true),
            1
        )
        XCTAssertEqual(
            NookBackSwipePolicy.minimumGestureAmount(isDirectionInvertedFromDevice: false),
            -1
        )
        XCTAssertEqual(
            NookBackSwipePolicy.maximumGestureAmount(isDirectionInvertedFromDevice: false),
            0
        )
    }

    func testDiscreteFallbackUsesAppKitRightSwipeDirection() {
        XCTAssertTrue(NookBackSwipePolicy.isDiscreteBackSwipe(deltaX: -1, deltaY: 0))
        XCTAssertFalse(NookBackSwipePolicy.isDiscreteBackSwipe(deltaX: 1, deltaY: 0))
        XCTAssertFalse(NookBackSwipePolicy.isDiscreteBackSwipe(deltaX: -0.2, deltaY: 1))
    }
}
