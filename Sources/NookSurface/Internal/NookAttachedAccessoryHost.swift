// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Renders a host accessory as part of the same panel as the nook.
struct NookAttachedAccessoryHost: View {
    let content: AnyView
    let backdrop: NookBackdrop
    let style: NookAttachedAccessoryStyle
    @State private var contentSize: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var isPresented: Bool {
        contentSize.width > 0 && contentSize.height > 0
    }

    var body: some View {
        content
            .onGeometryChange(for: CGSize.self, of: \.size) { contentSize = $0 }
            .padding(.top, isPresented ? style.contentInsets.top : 0)
            .padding(.bottom, isPresented ? style.contentInsets.bottom : 0)
            .padding(.leading, isPresented ? style.contentInsets.leading : 0)
            .padding(.trailing, isPresented ? style.contentInsets.trailing : 0)
            .background {
                if isPresented {
                    NookBackdropView(backdrop: backdrop, shape: shape)
                        .transition(.opacity)
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .fixedSize()
            .opacity(isPresented ? 1 : 0)
            .offset(y: isPresented || reduceMotion ? 0 : style.insertionOffset)
            .padding(.top, isPresented ? style.gap : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : style.animation, value: isPresented)
    }
}
