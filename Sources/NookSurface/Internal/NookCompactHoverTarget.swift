// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// The compact chrome's final, non-animated interaction geometry in AppKit screen coordinates.
///
/// SwiftUI keeps the visual compact conversion spring interruptible, but pointer admission must
/// follow the logical target state immediately. Otherwise the animated presentation shape briefly
/// leaves a hoverable "ghost" of the expanded surface after that surface is no longer visible.
struct NookCompactHoverTarget {
    static let notchCornerRadii: (top: CGFloat, bottom: CGFloat) = (top: 6, bottom: 14)

    let screenFrame: CGRect

    private let shape: NookShape

    init?(
        panelFrame: CGRect,
        form: NookChromeForm,
        notchSize: CGSize,
        menubarHeight: CGFloat,
        leadingWidth: CGFloat?,
        trailingWidth: CGFloat?,
        leadingSlotDisabled: Bool = false,
        trailingSlotDisabled: Bool = false
    ) {
        guard let leadingWidth = leadingSlotDisabled ? 0 : leadingWidth,
            let trailingWidth = trailingSlotDisabled ? 0 : trailingWidth
        else { return nil }

        let values = [
            panelFrame.origin.x,
            panelFrame.origin.y,
            panelFrame.width,
            panelFrame.height,
            notchSize.width,
            notchSize.height,
            menubarHeight,
            leadingWidth,
            trailingWidth,
        ]
        guard values.allSatisfy({ $0.isFinite }),
            panelFrame.width > 0,
            panelFrame.height > 0,
            notchSize.width > 0,
            notchSize.height > 0,
            menubarHeight >= 0,
            leadingWidth >= 0,
            trailingWidth >= 0
        else { return nil }

        let radii = Self.cornerRadii(for: form, notchHeight: notchSize.height)
        let gapWidth = form == .floating ? 8 : notchSize.width
        let width = leadingWidth + gapWidth + trailingWidth + (radii.top * 2)
        let topInset = form == .floating ? menubarHeight + 8 : 0
        let horizontalOffset = form == .floating ? 0 : (trailingWidth - leadingWidth) / 2

        screenFrame = CGRect(
            x: panelFrame.midX - (width / 2) + horizontalOffset,
            y: panelFrame.maxY - topInset - notchSize.height,
            width: width,
            height: notchSize.height
        )
        shape = NookShape(
            form: form,
            topCornerRadius: radii.top,
            bottomCornerRadius: radii.bottom
        )
    }

    /// Whether an AppKit screen-space point is inside the final visible compact chrome.
    func contains(screenPoint: CGPoint) -> Bool {
        guard screenPoint.x.isFinite,
            screenPoint.y.isFinite,
            screenFrame.contains(screenPoint)
        else { return false }

        // AppKit screen coordinates are y-up; SwiftUI Shape paths are y-down.
        let localPoint = CGPoint(
            x: screenPoint.x - screenFrame.minX,
            y: screenFrame.maxY - screenPoint.y
        )
        let localBounds = CGRect(origin: .zero, size: screenFrame.size)
        return shape.path(in: localBounds).contains(localPoint)
    }

    static func cornerRadii(
        for form: NookChromeForm,
        notchHeight: CGFloat
    ) -> (top: CGFloat, bottom: CGFloat) {
        switch form {
            case .notch:
                return notchCornerRadii
            case .floating:
                let radius = max(notchHeight / 2, 8)
                return (top: radius, bottom: radius)
        }
    }
}
