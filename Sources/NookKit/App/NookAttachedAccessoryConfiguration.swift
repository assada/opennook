// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import NookSurface
import SwiftUI

/// Host content attached beneath the expanded nook using framework-owned chrome.
///
/// The content may render `EmptyView` while it has nothing to show. OpenNook measures
/// that semantic content and owns the accessory's appearance, dismissal geometry,
/// hover continuity, display placement, and reduced-motion behavior.
public struct NookAttachedAccessoryConfiguration: Sendable {
    public var style: NookAttachedAccessoryStyle
    public var content: @Sendable @MainActor () -> AnyView

    public init<Content: View & Sendable>(
        style: NookAttachedAccessoryStyle = .standard,
        @ViewBuilder content: @escaping @Sendable @MainActor () -> Content
    ) {
        self.style = style
        self.content = { AnyView(content()) }
    }
}
