// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License. A copy is included at /LICENSE-MIT-NOOKSURFACE.

import AppKit

/// Observes trackpad page gestures before nested SwiftUI scroll views consume them.
///
/// This is an application-local event monitor, scoped to one nook panel. It does not
/// install a global event tap and therefore does not require Input Monitoring access.
@MainActor
final class NookBackSwipeMonitor {
    private weak var window: NSWindow?
    private let isEnabled: @MainActor () -> Bool
    private let perform: @MainActor () -> Void
    private var eventMonitor: Any?
    private var isTracking = false
    private var didPerformTrackedGesture = false

    init(
        window: NSWindow,
        isEnabled: @escaping @MainActor () -> Bool,
        perform: @escaping @MainActor () -> Void
    ) {
        self.window = window
        self.isEnabled = isEnabled
        self.perform = perform
    }

    func start() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .swipe]
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func stop() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
        isTracking = false
        didPerformTrackedGesture = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard
            let window,
            event.windowNumber == window.windowNumber,
            isEnabled()
        else { return event }

        switch event.type {
            case .scrollWheel:
                return handleScrollWheel(event)
            case .swipe:
                return handleDiscreteSwipe(event)
            default:
                return event
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> NSEvent? {
        let isDirectionInvertedFromDevice = event.isDirectionInvertedFromDevice

        guard
            !isTracking,
            NSEvent.isSwipeTrackingFromScrollEventsEnabled,
            event.hasPreciseScrollingDeltas,
            event.phase.contains(.began),
            NookBackSwipePolicy.isFluidBackSwipe(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY,
                isDirectionInvertedFromDevice: isDirectionInvertedFromDevice
            )
        else { return event }

        isTracking = true
        didPerformTrackedGesture = false
        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: NookBackSwipePolicy.minimumGestureAmount(
                isDirectionInvertedFromDevice: isDirectionInvertedFromDevice
            ),
            max: NookBackSwipePolicy.maximumGestureAmount(
                isDirectionInvertedFromDevice: isDirectionInvertedFromDevice
            )
        ) { [weak self] gestureAmount, phase, isComplete, _ in
            guard let self else { return }

            let shouldNavigate =
                !self.didPerformTrackedGesture
                && self.isEnabled()
                && NookBackSwipePolicy.shouldNavigateBack(
                    gestureAmount: gestureAmount,
                    phase: phase,
                    isDirectionInvertedFromDevice: isDirectionInvertedFromDevice
                )

            if shouldNavigate {
                self.didPerformTrackedGesture = true
                self.perform()
            }

            guard isComplete else { return }
            self.isTracking = false
            self.didPerformTrackedGesture = false
        }

        // The tracking loop owns the gesture after the initial horizontal event.
        return nil
    }

    private func handleDiscreteSwipe(_ event: NSEvent) -> NSEvent? {
        guard
            NookBackSwipePolicy.isDiscreteBackSwipe(
                deltaX: event.deltaX,
                deltaY: event.deltaY
            )
        else { return event }

        perform()
        return nil
    }
}

enum NookBackSwipePolicy {
    /// A deliberate drag can commit before release once it crosses half a page.
    private static let trackingCommitThreshold: CGFloat = 0.5

    /// A flick has low displacement but clear intent. Commit it on finger-up instead of
    /// waiting for AppKit's settling animation to extrapolate it to a full page.
    private static let releaseCommitThreshold: CGFloat = 0.08

    static func minimumGestureAmount(isDirectionInvertedFromDevice: Bool) -> CGFloat {
        isDirectionInvertedFromDevice ? 0 : -1
    }

    static func maximumGestureAmount(isDirectionInvertedFromDevice: Bool) -> CGFloat {
        isDirectionInvertedFromDevice ? 1 : 0
    }

    static func isHorizontal(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        abs(deltaX) > abs(deltaY) && deltaX != 0
    }

    static func isFluidBackSwipe(
        deltaX: CGFloat,
        deltaY: CGFloat,
        isDirectionInvertedFromDevice: Bool
    ) -> Bool {
        guard isHorizontal(deltaX: deltaX, deltaY: deltaY) else { return false }
        // `scrollingDeltaX` follows the user's content-scrolling preference. A physical
        // two-finger swipe to the right is positive for Natural scrolling and negative
        // when that preference is disabled.
        return isDirectionInvertedFromDevice ? deltaX > 0 : deltaX < 0
    }

    static func shouldNavigateBack(
        gestureAmount: CGFloat,
        phase: NSEvent.Phase,
        isDirectionInvertedFromDevice: Bool
    ) -> Bool {
        guard !phase.contains(.cancelled) else { return false }

        let backwardProgress =
            isDirectionInvertedFromDevice
            ? gestureAmount
            : -gestureAmount

        if phase.contains(.changed) {
            return backwardProgress >= trackingCommitThreshold
        }

        if phase.contains(.ended) {
            return backwardProgress >= releaseCommitThreshold
        }

        // Never navigate from AppKit's delayed settling callbacks. A gesture either
        // commits while active/on finger-up or remains cancelled.
        return false
    }

    static func isDiscreteBackSwipe(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        deltaX < 0 && abs(deltaX) > abs(deltaY)
    }
}
