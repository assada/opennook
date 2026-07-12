// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import XCTest

@testable import NookSurface

final class NookCompactGeometryTests: XCTestCase {

    private let panelSize = CGSize(width: 1512, height: 450)

    private func notchGeometry(
        notchSize: CGSize = CGSize(width: 180, height: 34),
        leadingWidth: CGFloat = 40,
        trailingWidth: CGFloat = 24
    ) -> NookCompactGeometry {
        NookCompactGeometry(
            form: .notch,
            notchSize: notchSize,
            menubarHeight: 34,
            leadingWidth: leadingWidth,
            trailingWidth: trailingWidth
        )
    }

    func testNotchGeometryUsesSharedLayoutMetrics() throws {
        let geometry = notchGeometry()

        XCTAssertEqual(geometry.cornerRadii.top, 6)
        XCTAssertEqual(geometry.cornerRadii.bottom, 14)
        XCTAssertEqual(geometry.horizontalPadding, 6)
        XCTAssertEqual(geometry.gapWidth, 180)
        XCTAssertEqual(geometry.topInset, 0)
        XCTAssertEqual(geometry.structuralMinimumWidth, 192)
        XCTAssertEqual(geometry.horizontalOffset, -8)
        XCTAssertEqual(geometry.size, CGSize(width: 256, height: 34))
        XCTAssertEqual(
            try XCTUnwrap(geometry.frame(in: panelSize)),
            CGRect(x: 620, y: 0, width: 256, height: 34)
        )
        XCTAssertEqual(NookCompactGeometry.slotHorizontalInset, 8)
        XCTAssertEqual(NookCompactGeometry.slotTopInset, 4)
        XCTAssertEqual(NookCompactGeometry.slotBottomInset, 8)
    }

    func testFloatingGeometryUsesSharedLayoutMetrics() throws {
        let geometry = NookCompactGeometry(
            form: .floating,
            notchSize: CGSize(width: 180, height: 32),
            menubarHeight: 25,
            leadingWidth: 30,
            trailingWidth: 20
        )
        let floatingPanelSize = CGSize(width: 1200, height: 400)

        XCTAssertEqual(geometry.cornerRadii.top, 16)
        XCTAssertEqual(geometry.cornerRadii.bottom, 16)
        XCTAssertEqual(geometry.horizontalPadding, 16)
        XCTAssertEqual(geometry.gapWidth, 8)
        XCTAssertEqual(geometry.topInset, 33)
        XCTAssertEqual(geometry.structuralMinimumWidth, 0)
        XCTAssertEqual(geometry.horizontalOffset, 0)
        XCTAssertEqual(geometry.size, CGSize(width: 90, height: 32))
        XCTAssertEqual(
            try XCTUnwrap(geometry.frame(in: floatingPanelSize)),
            CGRect(x: 555, y: 33, width: 90, height: 32)
        )
    }

    func testContainmentUsesYDownPanelCoordinates() throws {
        let geometry = notchGeometry()
        let frame = try XCTUnwrap(geometry.frame(in: panelSize))

        XCTAssertTrue(
            geometry.contains(
                CGPoint(x: frame.minX + 26, y: frame.midY),
                in: panelSize
            ),
            "the visible leading compact lobe must remain immediately hoverable"
        )
        XCTAssertTrue(
            geometry.contains(
                CGPoint(x: frame.maxX - 18, y: frame.midY),
                in: panelSize
            ),
            "the visible trailing compact lobe must remain immediately hoverable"
        )
        XCTAssertFalse(
            geometry.contains(
                CGPoint(x: frame.midX, y: frame.maxY + 80),
                in: panelSize
            ),
            "the former expanded footprint below compact chrome must not remain hoverable"
        )
        XCTAssertFalse(
            geometry.contains(
                CGPoint(x: frame.minX + 1, y: frame.maxY - 1),
                in: panelSize
            ),
            "the curved corner must not fall back to rectangular hit testing"
        )
    }

    func testInvalidGeometryFailsClosed() {
        XCTAssertNotNil(
            notchGeometry(leadingWidth: 0, trailingWidth: 20).frame(in: panelSize),
            "a measured zero-width slot is valid compact geometry"
        )
        XCTAssertNil(notchGeometry().frame(in: .zero))
        XCTAssertFalse(
            notchGeometry(leadingWidth: .nan).contains(
                CGPoint(x: 640, y: 17),
                in: panelSize
            )
        )
        XCTAssertFalse(
            notchGeometry().contains(
                CGPoint(x: CGFloat.nan, y: 17),
                in: panelSize
            )
        )
    }
}
