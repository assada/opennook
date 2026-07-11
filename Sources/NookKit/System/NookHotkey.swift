// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Carbon

/// A user-configurable global hotkey. Stores the Carbon virtual key code and modifier
/// mask needed by ``HotkeyController/register(_:keyCode:modifiers:handler:)``, plus a
/// display symbol for the non-modifier key (the modifier glyphs are derived).
public struct NookHotkey: Equatable, Codable, Sendable {
    /// Carbon `kVK_*` virtual key code. Matches `NSEvent.keyCode`.
    public var keyCode: UInt32
    /// Carbon modifier mask (`cmdKey | optionKey | controlKey | shiftKey`).
    public var carbonModifiers: UInt32
    /// Display glyph for the non-modifier key, e.g. `";"`, `"A"`, `"Space"`.
    public var keySymbol: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, keySymbol: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keySymbol = keySymbol
    }

    /// The default shortcut: ⌥ Space.
    public static let `default` = NookHotkey(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey),
        keySymbol: "Space"
    )

    /// Modifier glyphs in canonical macOS order (⌃⌥⇧⌘).
    public var modifierSymbols: [String] {
        var symbols: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols.append("⌘") }
        return symbols
    }

    /// Every glyph to render, modifiers first then the key - e.g. `["⌥", "Space"]`.
    public var displaySymbols: [String] { modifierSymbols + [keySymbol] }

    /// Flattened display string, e.g. `"⌥Space"`.
    public var display: String { displaySymbols.joined() }

    /// AppKit key-equivalent character used by `NSMenuItem`. Named keys use the
    /// control characters AppKit expects; printable keys are normalized to lowercase.
    public var menuKeyEquivalent: String {
        switch keySymbol {
            case "Space": " "
            case "↩": "\r"
            case "⇥": "\t"
            case "⌫": "\u{8}"
            case "⌦": "\u{7F}"
            case "←": "\u{F702}"
            case "→": "\u{F703}"
            case "↓": "\u{F701}"
            case "↑": "\u{F700}"
            case "F1": "\u{F704}"
            case "F2": "\u{F705}"
            case "F3": "\u{F706}"
            case "F4": "\u{F707}"
            case "F5": "\u{F708}"
            case "F6": "\u{F709}"
            case "F7": "\u{F70A}"
            case "F8": "\u{F70B}"
            case "F9": "\u{F70C}"
            case "F10": "\u{F70D}"
            case "F11": "\u{F70E}"
            case "F12": "\u{F70F}"
            default: keySymbol.lowercased()
        }
    }

    /// AppKit modifier mask paired with ``menuKeyEquivalent`` in a native menu.
    public var menuModifierMask: NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        return modifiers
    }
}

extension NookHotkey {
    /// Builds a hotkey from a captured `keyDown` event. Returns `nil` if the combination
    /// isn't usable as a global hotkey - it must include at least one of ⌘/⌥/⌃ (a
    /// shift-only or modifier-less key makes a poor, conflict-prone global shortcut).
    public init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        let primaryModifiers = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
        guard carbon & primaryModifiers != 0 else { return nil }

        let symbol = NookHotkey.keySymbol(for: event)
        guard !symbol.isEmpty else { return nil }

        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: carbon, keySymbol: symbol)
    }

    /// Human-readable glyph for a captured key. Named keys (arrows, space, function row)
    /// map by key code; everything else falls back to the uppercased typed character.
    private static func keySymbol(for event: NSEvent) -> String {
        if let named = namedKeys[event.keyCode] {
            return named
        }
        guard let character = event.charactersIgnoringModifiers?.first else {
            return ""
        }
        if character.isLetter || character.isNumber || "`-=[]\\;',./".contains(character) {
            return String(character).uppercased()
        }
        return ""
    }

    private static let namedKeys: [UInt16: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}

// MARK: - Persistence

enum NookHotkeyStore {
    private static let defaultsKey = "opennook.hotkey.v1"

    static func load() -> NookHotkey {
        load(default: .default)
    }

    /// Loads the persisted value, falling back to `fallback` (rather than `.default`)
    /// when nothing is persisted or the record is unreadable. The fallback is the host's
    /// launch seed (see ``NookPreferenceDefaults``) and is never written here.
    static func load(default fallback: NookHotkey) -> NookHotkey {
        guard let data = NookPreferenceStorage.defaults.data(forKey: defaultsKey) else {
            return fallback
        }
        return (try? JSONDecoder().decode(NookHotkey.self, from: data)) ?? fallback
    }

    static func save(_ hotkey: NookHotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            NookPreferenceStorage.defaults.set(data, forKey: defaultsKey)
        }
    }

    static func clear() {
        NookPreferenceStorage.defaults.removeObject(forKey: defaultsKey)
    }
}
