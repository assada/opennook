// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import Foundation
import SwiftUI

/// One-shot peripheral feedback request. Held by ``Nook`` and consumed by ``NookFeedbackOverlay``.
///
/// `id` is a fresh UUID per event so the view's `.onChange` / equality plumbing can detect
/// rapid successive triggers and restart the animation rather than fall through as a no-op.
struct NookFeedbackEvent: Equatable {
    let id: UUID
    let startedAt: Date
    let effect: NookFeedback
    let duration: TimeInterval
    let tint: Color
    let respectsReduceMotion: Bool
    /// When `true`, the overlay loops the animation indefinitely instead of fading to clear after
    /// one cycle. The host clears the event (e.g., when the nook expands) to stop the loop.
    let repeats: Bool

    /// Longest interval that can be converted to nanoseconds without overflowing.
    /// This is intentionally a representability bound, not a UX-duration policy.
    private static let maximumPlayableDuration = TimeInterval(UInt64.max) / 1_000_000_000

    /// Only positive, finite, representable durations can produce a visible cue.
    /// Rejecting invalid values before they enter the view tree prevents an unpaused
    /// ``TimelineView`` from ticking forever while rendering only `Color.clear`, and
    /// prevents the clear deadline from trapping during duration conversion.
    static func isPlayableDuration(_ duration: TimeInterval) -> Bool {
        duration.isFinite && duration > 0 && duration <= maximumPlayableDuration
    }

    var hasPlayableDuration: Bool {
        Self.isPlayableDuration(duration)
    }

    /// Starts a queued cue from the beginning when the chrome becomes visible.
    /// A hidden request's original timestamp may be older than its entire duration;
    /// carrying it through unchanged would replay nothing and still arm a fresh clear timer.
    func reanchored(at date: Date) -> NookFeedbackEvent {
        NookFeedbackEvent(
            id: id,
            startedAt: date,
            effect: effect,
            duration: duration,
            tint: tint,
            respectsReduceMotion: respectsReduceMotion,
            repeats: repeats
        )
    }
}
