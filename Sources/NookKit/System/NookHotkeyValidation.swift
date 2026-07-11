// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Carbon.HIToolbox

/// Validation shared by every hotkey-recording surface. Programmatic host defaults are
/// intentionally not constrained here; this protects user recording from combinations
/// that collide with OpenNook's own native menu commands.
enum NookHotkeyValidation {
    static func rejectionMessage(for hotkey: NookHotkey) -> String? {
        let primaryModifiers = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
        guard hotkey.carbonModifiers & primaryModifiers != 0 else {
            return "Use Command, Option, or Control with the key."
        }

        guard hotkey.carbonModifiers == UInt32(cmdKey) else { return nil }

        switch Int(hotkey.keyCode) {
            case kVK_ANSI_Q:
                return "\u{2318}Q is reserved for Quit. Choose another shortcut."
            case kVK_ANSI_Comma:
                return "\u{2318}, is reserved for Settings. Choose another shortcut."
            case kVK_ANSI_K:
                return "\u{2318}K is reserved for Stay Expanded. Choose another shortcut."
            default:
                return nil
        }
    }
}
