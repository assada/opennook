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
                isDirectionInvertedFromDevice: true
            )
        )
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0,
                phase: .ended,
                isDirectionInvertedFromDevice: true
            )
        )
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 1,
                phase: .cancelled,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testPhysicalGestureEndNavigatesBeforeSettlingCompletes() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0.7,
                phase: .ended,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testSettlingCallbackNeverNavigatesAfterFingerUp() {
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 1,
                phase: [],
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testSmallFlickCommitsImmediatelyOnFingerUp() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0.1,
                phase: .ended,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testMicroMovementRemainsCancelledOnFingerUp() {
        XCTAssertFalse(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0.03,
                phase: .ended,
                isDirectionInvertedFromDevice: true
            )
        )
    }

    func testDeliberateDragCommitsBeforeFingerUp() {
        XCTAssertTrue(
            NookBackSwipePolicy.shouldNavigateBack(
                gestureAmount: 0.6,
                phase: .changed,
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
