// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-level identity surfaced through the framework chrome.
///
/// Strings here name the *host product* (the `.app` the user installed), not any
/// individual module — they are how the chrome labels itself across the multi-module
/// host's shared surface. The About card reads ``hostName`` and ``hostTagline``; the
/// show/hide hotkey label and the menu-bar fallback read ``hostName``.
///
/// A single-module host gets the defaults (`"Nook"` / `nil`) and behaves exactly as
/// before — change them by switching from ``NookApp/main(_:)-(NookConfiguration)`` to
/// ``NookHostConfiguration`` and setting ``NookHostConfiguration/branding``.
public struct NookHostBranding: Sendable, Equatable {
    /// Display name of the host product. Used in About, in the show/hide hotkey label
    /// ("Show \(hostName)"), and in the menu-bar fallback's "Show \(hostName)" / icon
    /// accessibility text.
    public var hostName: String

    /// One-line "about" tagline. `nil` falls back to the framework's stock line, which
    /// describes the host as built with OpenNook.
    public var hostTagline: String?

    public init(hostName: String = "Nook", hostTagline: String? = nil) {
        self.hostName = hostName
        self.hostTagline = hostTagline
    }

    /// The single-module / unconfigured-host default. Reproduces the demo's strings
    /// exactly so `NookApp.main { … }` is unchanged.
    public static let `default` = NookHostBranding()
}

private struct NookHostBrandingKey: EnvironmentKey {
    static let defaultValue: NookHostBranding = .default
}

public extension EnvironmentValues {
    /// Host branding (``NookHostBranding``) injected by the expanded router so any
    /// framework chrome view can read it from the environment instead of taking it
    /// through every init in the path.
    var nookHostBranding: NookHostBranding {
        get { self[NookHostBrandingKey.self] }
        set { self[NookHostBrandingKey.self] = newValue }
    }
}
