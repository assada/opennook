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
        guard
            !isTracking,
            NSEvent.isSwipeTrackingFromScrollEventsEnabled,
            event.hasPreciseScrollingDeltas,
            event.phase.contains(.began),
            NookBackSwipePolicy.isHorizontal(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY
            )
        else { return event }

        isTracking = true
        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: NookBackSwipePolicy.minimumGestureAmount,
            max: NookBackSwipePolicy.maximumGestureAmount
        ) { [weak self] gestureAmount, _, isComplete, _ in
            guard let self else { return }

            if isComplete {
                self.isTracking = false
            }

            guard
                self.isEnabled(),
                NookBackSwipePolicy.shouldNavigateBack(
                    gestureAmount: gestureAmount,
                    isComplete: isComplete
                )
            else { return }

            self.perform()
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
