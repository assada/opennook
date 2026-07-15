// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Renders a host accessory as part of the same panel as the nook.
struct NookAttachedAccessoryHost: View {
    let content: AnyView
    let backdrop: NookBackdrop
    let style: NookAttachedAccessoryStyle
    @State private var contentSize: CGSize = .zero
    @State private var requestedPresentation: Bool?
    @State private var stagesInitialInsertion = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var isPresented: Bool {
        let hasContent = contentSize.width > 0 && contentSize.height > 0
        return hasContent && (requestedPresentation ?? true)
    }

    private var presentedSize: CGSize {
        CGSize(
            width: contentSize.width + style.contentInsets.leading + style.contentInsets.trailing,
            height: contentSize.height + style.contentInsets.top + style.contentInsets.bottom
        )
    }

    private var presentationAnimation: Animation {
        guard !reduceMotion else { return .easeOut(duration: 0.09) }
        guard isPresented else { return style.motion.removalAnimation }
        return stagesInitialInsertion
            ? style.motion.insertionAnimation.delay(style.motion.initialInsertionDelay)
            : style.motion.insertionAnimation
    }

    var body: some View {
        content
            .fixedSize()
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
            .frame(
                width: isPresented ? presentedSize.width : 0,
                height: isPresented ? presentedSize.height : 0,
                alignment: .top
            )
            .clipped()
            .contentShape(shape)
            .opacity(isPresented ? 1 : 0)
            .offset(y: isPresented || reduceMotion ? 0 : style.motion.insertionOffset)
            .padding(.top, isPresented ? style.gap : 0)
            .allowsHitTesting(isPresented)
            .accessibilityHidden(!isPresented)
            .animation(presentationAnimation, value: isPresented)
            .onPreferenceChange(NookAttachedAccessoryPresentationPreferenceKey.self) {
                requestedPresentation = $0
            }
            .task {
                // The host is mounted as the main nook starts expanding. Content measured
                // in this short window belongs to the same reveal and should enter near the
                // end of that motion. Content that appears later remains immediate.
                try? await Task.sleep(for: .milliseconds(80))
                stagesInitialInsertion = false
            }
    }
}
