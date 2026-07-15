// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// Renders a host accessory as part of the same panel as the nook.
struct NookAttachedAccessoryHost: View {
    let content: AnyView
    let backdrop: NookBackdrop
    let style: NookAttachedAccessoryStyle
    let isChromeExpanded: Bool
    let chromeDismissalRetention: Duration
    @State private var contentSize: CGSize = .zero
    @State private var requestedPresentation: Bool?
    @State private var occupiesLayout = false
    @State private var surfaceVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var presentationRequested: Bool {
        isChromeExpanded && hasContent && (requestedPresentation ?? true)
    }

    private var hasContent: Bool {
        contentSize.width > 0 && contentSize.height > 0
    }

    private var presentedSize: CGSize {
        CGSize(
            width: contentSize.width + style.contentInsets.leading + style.contentInsets.trailing,
            height: contentSize.height + style.contentInsets.top + style.contentInsets.bottom
        )
    }

    var body: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size) { contentSize = $0 }
            .padding(.top, hasContent ? style.contentInsets.top : 0)
            .padding(.bottom, hasContent ? style.contentInsets.bottom : 0)
            .padding(.leading, hasContent ? style.contentInsets.leading : 0)
            .padding(.trailing, hasContent ? style.contentInsets.trailing : 0)
            .background {
                if hasContent {
                    NookBackdropView(backdrop: backdrop, shape: shape)
                }
            }
            .clipShape(shape)
            // Keep the gap inside the retained layout. While the nook closes, the host
            // remains in this VStack long enough for its y-position to follow the
            // shrinking chrome instead of being frozen by a removal transition.
            .padding(.top, hasContent ? style.gap : 0)
            .frame(
                width: occupiesLayout ? presentedSize.width : 0,
                height: occupiesLayout ? presentedSize.height + style.gap : 0,
                alignment: .top
            )
            .clipped()
            .contentShape(shape)
            .opacity(surfaceVisible ? 1 : 0)
            .blur(radius: surfaceVisible || reduceMotion ? 0 : style.motion.blurRadius)
            .allowsHitTesting(surfaceVisible)
            .accessibilityHidden(!surfaceVisible)
            .onPreferenceChange(NookAttachedAccessoryPresentationPreferenceKey.self) {
                requestedPresentation = $0
            }
            .task(id: presentationRequested) {
                await updatePresentation(presentationRequested)
            }
    }

    @MainActor
    private func updatePresentation(_ shouldPresent: Bool) async {
        if shouldPresent {
            // Reserve the shelf's final layout immediately but keep it visually absent.
            // Its y-position now follows the nook's own expanding geometry, and only the
            // subtle surface reveal is delayed until the primary motion is nearly done.
            let transaction = Transaction(animation: nil)
            withTransaction(transaction) {
                occupiesLayout = true
                surfaceVisible = false
            }

            guard !reduceMotion else {
                surfaceVisible = true
                return
            }

            try? await Task.sleep(for: .seconds(max(style.motion.revealDelay, 0)))
            guard !Task.isCancelled else { return }
            withAnimation(style.motion.revealAnimation) {
                surfaceVisible = true
            }
            return
        }

        let wasFollowingChrome = !isChromeExpanded && occupiesLayout
        let dismissalAnimation: Animation =
            reduceMotion
            ? .easeOut(duration: 0.09)
            : style.motion.dismissalAnimation
        withAnimation(dismissalAnimation) {
            surfaceVisible = false
        }

        guard occupiesLayout else { return }
        let retention =
            wasFollowingChrome
            ? chromeDismissalRetention
            : Duration.seconds(max(style.motion.dismissalDuration, 0))
        try? await Task.sleep(for: retention)
        guard !Task.isCancelled else { return }

        // By now the shelf is visually gone. Releasing its layout without animation
        // cannot create the vertical squash that the user just watched us remove.
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            occupiesLayout = false
        }
    }
}
