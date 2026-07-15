// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Keeps attached semantic content mounted while the nook surface animates its visibility.
///
/// Use this wrapper when presentation can change independently of the content itself. The
/// surface remains responsible for layout, hit testing, clipping, backdrop, and motion.
public struct NookAttachedAccessoryContent<Content: View>: View {
    private let isPresented: Bool
    private let content: Content

    public init(
        isPresented: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.isPresented = isPresented
        self.content = content()
    }

    public var body: some View {
        content.preference(
            key: NookAttachedAccessoryPresentationPreferenceKey.self,
            value: isPresented
        )
    }
}

struct NookAttachedAccessoryPresentationPreferenceKey: PreferenceKey {
    static let defaultValue: Bool? = nil

    static func reduce(value: inout Bool?, nextValue: () -> Bool?) {
        if let nextValue = nextValue() {
            value = nextValue
        }
    }
}
