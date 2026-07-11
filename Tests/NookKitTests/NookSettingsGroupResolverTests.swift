// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import XCTest

@testable import NookKit

final class NookSettingsGroupResolverTests: XCTestCase {
    func testDefaultExpansionFallsThroughWhenAppearanceIsHidden() {
        let configuration = NookBuiltInSettingsConfiguration(
            hiddenItems: [.theme, .surface, .layout, .accent, .backdropStrength]
        )

        XCTAssertEqual(
            configuration.resolvedInitiallyExpandedGroupIDs(hostSections: []),
            ["Display"]
        )
    }

    func testDefaultExpansionSkipsEmptyCustomGroup() {
        let configuration = NookBuiltInSettingsConfiguration(
            groups: [
                NookSettingsGroup(id: "empty", title: "Empty", items: []),
                NookSettingsGroup(
                    id: "general",
                    title: "General",
                    items: [.builtIn(.display)]
                ),
            ]
        )

        XCTAssertEqual(
            configuration.resolvedInitiallyExpandedGroupIDs(hostSections: []),
            ["general"]
        )
    }

    func testDefaultExpansionSkipsCustomGroupWhoseItemsAreHidden() {
        let configuration = NookBuiltInSettingsConfiguration(
            hiddenItems: [.theme],
            groups: [
                NookSettingsGroup(
                    id: "hidden",
                    title: "Hidden",
                    items: [.builtIn(.theme)]
                ),
                NookSettingsGroup(
                    id: "general",
                    title: "General",
                    items: [.builtIn(.display)]
                ),
            ]
        )

        XCTAssertEqual(
            configuration.resolvedInitiallyExpandedGroupIDs(hostSections: []),
            ["general"]
        )
    }

    func testExplicitEmptyExpansionSetIsPreserved() {
        let configuration = NookBuiltInSettingsConfiguration(
            initiallyExpandedGroupIDs: []
        )

        XCTAssertEqual(
            configuration.resolvedInitiallyExpandedGroupIDs(hostSections: []),
            []
        )
    }
}
