// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Motion tokens for content attached to an expanded nook.
///
/// The accessory is a secondary surface, so it should arrive slightly ahead of
/// the main nook's settling tail instead of appearing to chase it.
public struct NookAttachedAccessoryMotion: Equatable, Sendable {
    public var insertionOffset: CGFloat
    public var initialInsertionDelay: TimeInterval
    public var insertionResponse: TimeInterval
    public var insertionDampingFraction: Double
    public var insertionBlendDuration: TimeInterval
    public var removalDuration: TimeInterval

    public init(
        insertionOffset: CGFloat = -4,
        initialInsertionDelay: TimeInterval = 0.18,
        insertionResponse: TimeInterval = 0.23,
        insertionDampingFraction: Double = 0.92,
        insertionBlendDuration: TimeInterval = 0.03,
        removalDuration: TimeInterval = 0.14
    ) {
        self.insertionOffset = insertionOffset
        self.initialInsertionDelay = initialInsertionDelay
        self.insertionResponse = insertionResponse
        self.insertionDampingFraction = insertionDampingFraction
        self.insertionBlendDuration = insertionBlendDuration
        self.removalDuration = removalDuration
    }

    public static let standard = NookAttachedAccessoryMotion()

    var insertionAnimation: Animation {
        .spring(
            response: insertionResponse,
            dampingFraction: insertionDampingFraction,
            blendDuration: insertionBlendDuration
        )
    }

    var removalAnimation: Animation {
        .easeOut(duration: removalDuration)
    }
}
