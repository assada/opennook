// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// One source of truth for the compact chrome's visual and interaction geometry.
///
/// `NookView` consumes the layout metrics directly, while hover admission uses the
/// resulting frame and shape in the panel's stable SwiftUI coordinate space. Keeping
/// both consumers on this value prevents a visual padding or spacing change from
/// silently leaving a different hit target behind.
struct NookCompactGeometry {
    static let slotHorizontalInset: CGFloat = 8
    static let slotTopInset: CGFloat = 4
    static let slotBottomInset: CGFloat = 8

    private static let floatingGap: CGFloat = 8
    private static let floatingTopSpacing: CGFloat = 8
    private static let notchCornerRadii: (top: CGFloat, bottom: CGFloat) = (top: 6, bottom: 14)

    let form: NookChromeForm
    let notchSize: CGSize
    let menubarHeight: CGFloat
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat

    var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch form {
            case .notch:
                return Self.notchCornerRadii
            case .floating:
                let radius = max(notchSize.height / 2, 8)
                return (top: radius, bottom: radius)
        }
    }

    var horizontalPadding: CGFloat { cornerRadii.top }
    var gapWidth: CGFloat { form == .floating ? Self.floatingGap : notchSize.width }
    var topInset: CGFloat { form == .floating ? menubarHeight + Self.floatingTopSpacing : 0 }

    /// The compact chrome's visual floor before slot content contributes its intrinsic width.
    /// Keep this independent from measured slot widths so a new compact cycle cannot render
    /// its minimum frame against measurements retained from the prior cycle.
    var structuralMinimumWidth: CGFloat {
        form == .floating ? 0 : gapWidth + (horizontalPadding * 2)
    }

    var horizontalOffset: CGFloat {
        form == .floating ? 0 : (trailingWidth - leadingWidth) / 2
    }

    var size: CGSize {
        CGSize(
            width: leadingWidth + gapWidth + trailingWidth + (horizontalPadding * 2),
            height: notchSize.height
        )
    }

    func frame(in panelSize: CGSize) -> CGRect? {
        guard isValid, panelSize.width.isFinite, panelSize.height.isFinite,
            panelSize.width > 0, panelSize.height > 0
        else { return nil }

        return CGRect(
            x: (panelSize.width - size.width) / 2 + horizontalOffset,
            y: topInset,
            width: size.width,
            height: size.height
        )
    }

    func contains(_ panelPoint: CGPoint, in panelSize: CGSize) -> Bool {
        guard panelPoint.x.isFinite,
            panelPoint.y.isFinite,
            let frame = frame(in: panelSize),
            frame.contains(panelPoint)
        else { return false }

        let localPoint = CGPoint(
            x: panelPoint.x - frame.minX,
            y: panelPoint.y - frame.minY
        )
        let localBounds = CGRect(origin: .zero, size: frame.size)
        return shape.path(in: localBounds).contains(localPoint)
    }

    private var shape: NookShape {
        NookShape(
            form: form,
            topCornerRadius: cornerRadii.top,
            bottomCornerRadius: cornerRadii.bottom
        )
    }

    private var isValid: Bool {
        let values = [
            notchSize.width,
            notchSize.height,
            menubarHeight,
            leadingWidth,
            trailingWidth,
        ]
        return values.allSatisfy { $0.isFinite }
            && notchSize.width > 0
            && notchSize.height > 0
            && menubarHeight >= 0
            && leadingWidth >= 0
            && trailingWidth >= 0
    }
}
