// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Motion tokens for content attached to an expanded nook.
///
/// The accessory's position is driven by the nook's own layout animation. These
/// tokens control only the secondary surface's delayed reveal and disappearance;
/// they deliberately do not add an independent slide or geometry collapse.
public struct NookAttachedAccessoryMotion: Equatable, Sendable {
    public var revealDelay: TimeInterval
    public var revealDuration: TimeInterval
    public var dismissalDuration: TimeInterval
    public var blurRadius: CGFloat

    public init(
        revealDelay: TimeInterval = 0.22,
        revealDuration: TimeInterval = 0.16,
        dismissalDuration: TimeInterval = 0.20,
        blurRadius: CGFloat = 5
    ) {
        self.revealDelay = revealDelay
        self.revealDuration = revealDuration
        self.dismissalDuration = dismissalDuration
        self.blurRadius = blurRadius
    }

    public static let standard = NookAttachedAccessoryMotion()

    var revealAnimation: Animation {
        .smooth(duration: max(revealDuration, 0))
    }

    var dismissalAnimation: Animation {
        .smooth(duration: max(dismissalDuration, 0))
    }
}
