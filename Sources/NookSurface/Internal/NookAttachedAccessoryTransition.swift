// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

extension AnyTransition {
    static func nookAttachedAccessoryCollapse(
        motion: NookAttachedAccessoryMotion
    ) -> AnyTransition {
        .modifier(
            active: NookAttachedAccessoryCollapseModifier(
                horizontalScale: motion.resolvedCollapsedWidthFraction,
                verticalScale: 0.01,
                offset: motion.insertionOffset
            ),
            identity: NookAttachedAccessoryCollapseModifier(
                horizontalScale: 1,
                verticalScale: 1,
                offset: 0
            )
        )
    }
}

private struct NookAttachedAccessoryCollapseModifier: ViewModifier {
    let horizontalScale: CGFloat
    let verticalScale: CGFloat
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: horizontalScale,
                y: verticalScale,
                anchor: .top
            )
            .offset(y: offset)
    }
}
