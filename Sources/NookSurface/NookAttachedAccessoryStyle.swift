// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Framework-owned layout and motion for content attached below an expanded nook.
///
/// Hosts provide only the accessory's semantic content. `NookSurface` owns its
/// placement in the live panel, hover continuity, backdrop, clipping, and motion.
public struct NookAttachedAccessoryStyle: Equatable, Sendable {
    public var gap: CGFloat
    public var cornerRadius: CGFloat
    public var contentInsets: NookEdgeInsets
    public var motion: NookAttachedAccessoryMotion

    public init(
        gap: CGFloat = 8,
        cornerRadius: CGFloat = 16,
        contentInsets: NookEdgeInsets = .init(top: 10, bottom: 10, leading: 12, trailing: 12),
        motion: NookAttachedAccessoryMotion = .standard
    ) {
        self.gap = gap
        self.cornerRadius = cornerRadius
        self.contentInsets = contentInsets
        self.motion = motion
    }

    public static let standard = NookAttachedAccessoryStyle()
}
