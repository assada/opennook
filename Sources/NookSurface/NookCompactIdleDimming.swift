// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import Foundation
import SwiftUI

/// Developer-configured idle treatment for the two compact slots flanking the notch.
///
/// When enabled, compact content remains fully visible until ``delay`` elapses without
/// Nook activity, then fades to ``dimmedOpacity``. Hover, lifecycle transitions, feedback,
/// drag entry, module switches, and explicit ``Nook/noteCompactActivity()`` calls restore
/// full opacity and restart the deadline.
///
/// The effect applies only to slot content. It never changes chrome geometry, hit testing,
/// the backdrop, or the notch shape.
public struct NookCompactIdleDimming: Sendable, Equatable {
    /// Time compact content stays fully visible after the most recent activity.
    /// Negative values are treated as zero.
    public var delay: Duration

    /// Slot-content opacity after the idle delay. Values are resolved safely into `0...1`;
    /// a non-finite value fails open to `1`.
    public var dimmedOpacity: Double

    /// Animation used when the idle deadline dims compact content.
    public var dimAnimation: Animation

    /// Animation used when activity restores compact content to full opacity.
    public var restoreAnimation: Animation

    public init(
        delay: Duration = .seconds(10),
        dimmedOpacity: Double = 0.55,
        dimAnimation: Animation = .easeInOut(duration: 0.7),
        restoreAnimation: Animation = .easeOut(duration: 0.15)
    ) {
        self.delay = delay
        self.dimmedOpacity = dimmedOpacity
        self.dimAnimation = dimAnimation
        self.restoreAnimation = restoreAnimation
    }

    /// Recommended idle treatment. Passing this value is opt-in; OpenNook leaves idle
    /// dimming disabled unless a host supplies a configuration.
    public static let standard = NookCompactIdleDimming()

    var resolvedDelay: Duration {
        max(delay, .zero)
    }

    var resolvedDimmedOpacity: Double {
        guard dimmedOpacity.isFinite else { return 1 }
        return min(max(dimmedOpacity, 0), 1)
    }
}
