// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import CoreGraphics

/// Buffers a real compact-hover event only while slot measurements are unavailable.
///
/// Readiness may replay that event once. Later layout changes cannot mint hover activity
/// on their own because a `true -> true` readiness update never yields a point.
struct NookCompactHoverAdmission {
    private(set) var pendingActivePoint: CGPoint?

    static func measurementsReady(
        leadingSlotDisabled: Bool,
        leadingSlotMeasured: Bool,
        trailingSlotDisabled: Bool,
        trailingSlotMeasured: Bool
    ) -> Bool {
        (leadingSlotDisabled || leadingSlotMeasured)
            && (trailingSlotDisabled || trailingSlotMeasured)
    }

    mutating func active(
        at point: CGPoint,
        measurementsReady: Bool
    ) -> CGPoint? {
        guard !measurementsReady else {
            pendingActivePoint = nil
            return point
        }
        pendingActivePoint = point
        return nil
    }

    mutating func measurementsChanged(
        from wasReady: Bool,
        to isReady: Bool
    ) -> CGPoint? {
        guard !wasReady, isReady else { return nil }
        defer { pendingActivePoint = nil }
        return pendingActivePoint
    }

    mutating func ended() {
        pendingActivePoint = nil
    }
}
