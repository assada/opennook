// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Preset accent colors for chrome controls. `.system` follows the macOS control accent.
public enum NookAccentPreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case red
    case orange
    case lime
    case green
    case teal
    case cyan
    case blue
    case violet
    case rose

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
            case .system: "System"
            case .red: "Red"
            case .orange: "Amber"
            case .lime: "Lime"
            case .green: "Green"
            case .teal: "Teal"
            case .cyan: "Cyan"
            case .blue: "Blue"
            case .violet: "Violet"
            case .rose: "Rose"
        }
    }

    public func color(fallbackSystem: Color = Color(nsColor: .controlAccentColor)) -> Color {
        switch self {
            case .system: fallbackSystem
            case .red: Color(red: 1.00, green: 0.36, blue: 0.41)
            case .orange: Color(red: 0.95, green: 0.65, blue: 0.35)
            case .lime: Color(red: 0.77, green: 0.91, blue: 0.36)
            case .green: Color(red: 0.27, green: 0.83, blue: 0.51)
            case .teal: Color(red: 0.36, green: 0.75, blue: 0.71)
            case .cyan: Color(red: 0.16, green: 0.66, blue: 0.88)
            case .blue: Color(red: 0.29, green: 0.55, blue: 1.00)
            case .violet: Color(red: 0.53, green: 0.42, blue: 1.00)
            case .rose: Color(red: 0.91, green: 0.42, blue: 0.64)
        }
    }
}
