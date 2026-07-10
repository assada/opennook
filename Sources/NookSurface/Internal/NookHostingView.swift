// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License. A copy is included at /LICENSE-MIT-NOOKSURFACE.

import AppKit
import SwiftUI

/// Root hosting view for the nook panel. It owns only panel-level responder behavior;
/// product navigation remains behind callbacks configured by the host layer.
final class NookHostingView<Content: View>: NSHostingView<Content> {
    var isBackSwipeEnabled: @MainActor () -> Bool = { false }
    var performBackSwipe: @MainActor () -> Void = {}

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal && isBackSwipeEnabled()
    }

    override func scrollWheel(with event: NSEvent) {
        guard
            isBackSwipeEnabled(),
            NSEvent.isSwipeTrackingFromScrollEventsEnabled,
            event.phase.contains(.began),
            NookBackSwipePolicy.isHorizontal(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY
            )
        else {
            super.scrollWheel(with: event)
            return
        }

        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: NookBackSwipePolicy.minimumGestureAmount,
            max: NookBackSwipePolicy.maximumGestureAmount
        ) { [weak self] gestureAmount, _, isComplete, _ in
            guard
                let self,
                self.isBackSwipeEnabled(),
                NookBackSwipePolicy.shouldNavigateBack(
                    gestureAmount: gestureAmount,
                    isComplete: isComplete
                )
            else { return }

            self.performBackSwipe()
        }
    }

    /// Fallback for systems configured to emit a discrete swipe event instead of
    /// scroll-backed fluid page tracking. AppKit reports a right swipe as `deltaX == -1`.
    override func swipe(with event: NSEvent) {
        guard
            isBackSwipeEnabled(),
            NookBackSwipePolicy.isDiscreteBackSwipe(
                deltaX: event.deltaX,
                deltaY: event.deltaY
            )
        else {
            super.swipe(with: event)
            return
        }

        performBackSwipe()
    }
}

enum NookBackSwipePolicy {
    static let minimumGestureAmount: CGFloat = -1
    static let maximumGestureAmount: CGFloat = 0

    static func isHorizontal(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        abs(deltaX) > abs(deltaY) && deltaX != 0
    }

    static func shouldNavigateBack(gestureAmount: CGFloat, isComplete: Bool) -> Bool {
        isComplete && gestureAmount <= -0.5
    }

    static func isDiscreteBackSwipe(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        deltaX < 0 && abs(deltaX) > abs(deltaY)
    }
}
