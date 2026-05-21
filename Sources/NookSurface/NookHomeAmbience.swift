// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Host apps publish a home-surface ambience tint via this preference. OpenNook paints it
/// behind the full expanded chrome (top bar + home), including edge and safe-area padding,
/// so the gradient is not clipped to the host home view bounds.
public struct NookHomeAmbiencePreferenceKey: PreferenceKey {
    public static var defaultValue: Color? { nil }

    public static func reduce(value: inout Color?, nextValue: () -> Color?) {
        value = nextValue() ?? value
    }
}

/// Top-to-bottom wash used when a host app selects a theme color in its home surface.
public struct NookHomeAmbienceBackground: View {
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        LinearGradient(
            colors: [
                color.opacity(0.34),
                color.opacity(0.16),
                color.opacity(0.06),
                color.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
