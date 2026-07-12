// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// An environment action that restores developer-configured compact slot dimming.
///
/// Host views use this when product activity is meaningful but invisible to the generic
/// surface, such as a generation starting, a counter changing, or background work finishing:
///
/// ```swift
/// @Environment(\.nookCompactActivity) private var noteCompactActivity
///
/// var body: some View {
///     StatusGlyph()
///         .onChange(of: model.status) { noteCompactActivity() }
/// }
/// ```
public struct NookCompactActivityAction: Sendable {
    private let action: @MainActor @Sendable () -> Void

    /// Creates an activity action. The default action is a safe no-op, which also makes
    /// it convenient to inject a spy in host previews and tests.
    public init(action: @escaping @MainActor @Sendable () -> Void = {}) {
        self.action = action
    }

    /// Restore compact content to full opacity and restart its idle deadline.
    @MainActor
    public func callAsFunction() {
        action()
    }
}

private struct NookCompactActivityEnvironmentKey: EnvironmentKey {
    static let defaultValue = NookCompactActivityAction()
}

extension EnvironmentValues {
    /// Reports host-defined activity to the enclosing Nook surface.
    ///
    /// Outside a Nook hierarchy, or when idle dimming is disabled, calling this action
    /// is a safe no-op.
    public var nookCompactActivity: NookCompactActivityAction {
        get { self[NookCompactActivityEnvironmentKey.self] }
        set { self[NookCompactActivityEnvironmentKey.self] = newValue }
    }
}
