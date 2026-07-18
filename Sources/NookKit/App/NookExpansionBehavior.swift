// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// How one coordinator-driven expansion should behave before the user engages it.
///
/// This is a per-presentation choice rather than a global chrome setting: a background
/// result can open as an unattended preview while the framework's hotkey remains an
/// explicit, persistent user action.
public enum NookExpansionBehavior: Sendable, Equatable {
    /// The user explicitly requested the expansion. It remains expanded until the
    /// normal user-driven lifecycle (toggle, Escape, or hover exit) compacts it.
    case userInitiated

    /// Compact automatically when no pointer, drag, keep-open, or presentation-pin
    /// engagement occurs before `timeout` elapses.
    ///
    /// The first engagement cancels this timeout for the rest of the current expansion.
    /// A later hover exit then follows the ordinary immediate auto-compact behavior.
    /// Negative timeouts are treated as zero.
    case unattended(timeout: Duration)

    var unattendedTimeout: Duration? {
        guard case .unattended(let timeout) = self else { return nil }
        return max(timeout, .zero)
    }
}
