// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import CoreGraphics

/// Pure sizing policy for the built-in Settings scroll viewport.
enum SettingsViewportSizing {
    static let fallbackMaximumHeight: CGFloat = 340
    private static let preferredMaximumHeight: CGFloat = 440
    private static let targetScreenFraction: CGFloat = 0.36

    /// Uses the visible height of the screen the nook actually targets. There is no fixed
    /// minimum: imposing one is what made short secondary displays overflow their panel.
    static func maximumHeight(targetScreenVisibleHeight: CGFloat) -> CGFloat {
        guard targetScreenVisibleHeight.isFinite, targetScreenVisibleHeight > 0 else {
            return fallbackMaximumHeight
        }
        return min(
            preferredMaximumHeight,
            targetScreenVisibleHeight * targetScreenFraction
        )
    }
}
