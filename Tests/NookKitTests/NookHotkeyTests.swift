// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Carbon
import XCTest
@testable import NookKit

final class NookHotkeyTests: XCTestCase {
    func testDefaultHotkeyDisplaysCanonicalGlyphs() {
        XCTAssertEqual(NookHotkey.default.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(NookHotkey.default.carbonModifiers, UInt32(optionKey))
        XCTAssertEqual(NookHotkey.default.displaySymbols, ["⌥", "Space"])
        XCTAssertEqual(NookHotkey.default.display, "⌥Space")
    }

    func testModifierSymbolsAreInCanonicalOrder() {
        let hotkey = NookHotkey(
            keyCode: 0,
            carbonModifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey),
            keySymbol: "A"
        )
        XCTAssertEqual(hotkey.modifierSymbols, ["⌃", "⌥", "⇧", "⌘"])
        XCTAssertEqual(hotkey.display, "⌃⌥⇧⌘A")
    }

    func testRoundTripThroughJSON() throws {
        let original = NookHotkey(
            keyCode: 49,
            carbonModifiers: UInt32(cmdKey | controlKey),
            keySymbol: "Space"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NookHotkey.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
