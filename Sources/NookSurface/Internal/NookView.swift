// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// The notch chrome itself: arches around the menu-bar notch, switches between expanded and
/// compact-with-side-slots, and paints the configured backdrop behind both.
struct NookView<Expanded, CompactLeading, CompactTrailing>: View
where Expanded: View, CompactLeading: View, CompactTrailing: View {
    @ObservedObject private var nook: Nook<Expanded, CompactLeading, CompactTrailing>
    @State private var compactLeadingWidth: CGFloat = 0
    @State private var compactTrailingWidth: CGFloat = 0
    @State private var hasMeasuredCompactLeading = false
    @State private var hasMeasuredCompactTrailing = false
    @State private var compactHoverAdmission = NookCompactHoverAdmission()
    @State private var trackedExpandedSize: CGSize = .zero
    @State private var ambientColor: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(nook: Nook<Expanded, CompactLeading, CompactTrailing>) {
        self.nook = nook
    }

    /// Safe-area strip the chrome reserves around the host's expanded content. Host-
    /// configurable per edge via ``NookStyle/expandedContentInsets``; the default
    /// reproduces the historical fixed geometry (0 top, 8 elsewhere).
    private var expandedContentInsets: NookEdgeInsets {
        nook.style.expandedContentInsets
    }

    /// `true` when the surface should render the free-floating panel instead of the
    /// notch-fused shape - a display with no notch, or a forced `.floating` presentation.
    private var isFloating: Bool {
        nook.layoutForm == .floating
    }

    /// Residual safe-area insets the host's expanded view can read via
    /// ``EnvironmentValues/nookContentInsets``. `.zero` while compact or hidden -
    /// no host expanded content is rendered in those states. The expanded value
    /// is the geometric clearance left over after the chrome's own paddings;
    /// see ``NookContentInsets/expanded(form:topCornerRadius:bottomCornerRadius:chromeSafeAreaInset:)``.
    private var contentInsets: NookContentInsets {
        guard nook.state == .expanded else { return .zero }
        return NookContentInsets.expanded(
            form: nook.layoutForm,
            topCornerRadius: nook.style.topCornerRadius,
            bottomCornerRadius: nook.style.bottomCornerRadius,
            chromeSafeAreaInsets: expandedContentInsets
        )
    }

    private var expandedCornerRadii: (top: CGFloat, bottom: CGFloat) {
        (top: nook.style.topCornerRadius, bottom: nook.style.bottomCornerRadius)
    }

    private var compactCornerRadii: (top: CGFloat, bottom: CGFloat) {
        compactGeometry.cornerRadii
    }

    /// Floating panels use convex corners - a card when expanded, a capsule when
    /// compact (radius = half the pill height). No notch ears to fuse, so the same
    /// radius applies to all four corners.
    private var floatingExpandedRadius: CGFloat { expandedCornerRadii.bottom }
    private var floatingCompactRadius: CGFloat { compactCornerRadii.top }

    /// Vertical gap that drops the floating panel clear of the menu bar. Zero in notch
    /// mode, where the chrome is meant to sit flush against the top edge.
    private var floatingTopInset: CGFloat {
        compactGeometry.topInset
    }

    private var minWidth: CGFloat {
        if nook.state == .compact { return compactGeometry.structuralMinimumWidth }
        // A floating panel is purely content-driven; only the notch shape needs a
        // minimum (the notch gap plus its ears).
        return isFloating ? 0 : nook.notchSize.width + (topCornerRadius * 2)
    }

    private var topCornerRadius: CGFloat {
        if isFloating {
            return nook.state == .expanded ? floatingExpandedRadius : floatingCompactRadius
        }
        return nook.state == .expanded ? expandedCornerRadii.top : compactCornerRadii.top
    }

    private var bottomCornerRadius: CGFloat {
        if isFloating {
            return nook.state == .expanded ? floatingExpandedRadius : floatingCompactRadius
        }
        return nook.state == .expanded ? expandedCornerRadii.bottom : compactCornerRadii.bottom
    }

    /// In compact mode, slot-width asymmetry shifts the whole shape so the gap stays centered on the notch.
    private var xOffset: CGFloat {
        nook.state == .compact ? compactXOffset : 0
    }

    /// Notch mode re-centers the shape on the physical notch when the leading/trailing
    /// slots differ in width. A floating pill has no notch to center on, so it stays put.
    private var compactXOffset: CGFloat {
        compactGeometry.horizontalOffset
    }

    /// Backdrop sits behind chrome content, both flattened into a single layer, then clipped
    /// to the animatable notch shape. Compositing as one group means the spring animation can
    /// scale content + backdrop atomically - no magic overshoot padding required to plug
    /// edge gaps mid-bounce.
    ///
    /// The matching `.contentShape(NookShape)` is critical: `.clipShape` only clips drawing,
    /// not hit-testing. Without it, the hover region falls back to the rectangular bounds -
    /// which extend down into the would-be-expanded area because the expanded content's
    /// `.fixedSize()` doesn't actually collapse to 0×0 when wrapped in a max-frame. Result:
    /// hovering in the empty space below a compact nook triggers the hover-grow animation.
    /// Hit-testing the same `NookShape` we render confines hover to the visible chrome.
    var body: some View {
        VStack(spacing: 0) {
            notchChrome

            if nook.state == .expanded, let accessory = nook.attachedAccessoryContent {
                NookAttachedAccessoryHost(
                    content: accessory,
                    backdrop: nook.backdrop,
                    style: nook.attachedAccessoryStyle
                )
                // The host owns insertion after its semantic content has been measured.
                // Applying another insertion transition here makes the accessory animate
                // twice and visually trail the main nook. Removal still follows the nook's
                // closing transaction so both surfaces leave as one composition.
                .transition(attachedAccessoryRemovalTransition)
            }
        }
        .fixedSize()
        .onContinuousHover(coordinateSpace: .global, perform: handleHover)
        .padding(.top, floatingTopInset)
        .animation(nook.effectiveConversionAnimation, value: nook.state)
        .animation(nook.effectiveConversionAnimation, value: [compactLeadingWidth, compactTrailingWidth])
    }

    private var notchChrome: some View {
        notchContent()
            .background { notchBackdrop() }
            .overlay { feedbackOverlay() }
            .environment(\.nookCompactActivity, compactActivityAction)
            .compositingGroup()
            .clipShape(notchShape)
            .contentShape(notchShape)
            .onChange(of: compactHoverMeasurementsReady) { wasReady, isReady in
                reconcilePendingCompactHover(from: wasReady, to: isReady)
            }
            .onChange(of: nook.state) { _, state in
                guard state != .compact else { return }
                compactHoverAdmission.ended()
            }
            .offset(x: xOffset)
            // Floating mode drops the panel below the menu bar; notch mode keeps it
            // flush to the top edge (inset 0). Applied outside the clipped chrome so it
            // shifts the whole shape without distorting it or the hover region.
    }

    private var attachedAccessoryRemovalTransition: AnyTransition {
        if reduceMotion {
            return .asymmetric(insertion: .identity, removal: .opacity)
        }
        return .asymmetric(
            insertion: .identity,
            removal: .offset(y: nook.attachedAccessoryStyle.motion.insertionOffset / 2)
                .combined(with: .opacity)
        )
    }

    /// Peripheral cue overlay. Sits above backdrop+content but inside the compositing group,
    /// so the shimmer stroke flattens with the chrome before the notch shape carves the visible
    /// region - no edge gaps mid-bounce, no spillover beyond the arch.
    private func feedbackOverlay() -> some View {
        NookFeedbackOverlay(
            event: nook.feedbackEvent,
            form: nook.layoutForm,
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            reduceMotion: reduceMotion
        )
    }

    private var notchShape: NookShape {
        NookShape(
            form: nook.layoutForm,
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    /// Admit pointer activity against logical geometry, not the spring's presentation tail.
    /// `.global` is panel-local here because `initializeWindow` edge-pins a full-panel
    /// `NSHostingView` root. The event point and `panelSize` therefore share one
    /// stable, y-down coordinate space.
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
            case .active(let location):
                let measurementsReady =
                    nook.state != .compact || compactHoverMeasurementsReady
                guard
                    let eventPoint = compactHoverAdmission.active(
                        at: location,
                        measurementsReady: measurementsReady
                    )
                else { return }
                admitHover(at: eventPoint)
            case .ended:
                compactHoverAdmission.ended()
                nook.updateHoverState(false)
        }
    }

    private var compactGeometry: NookCompactGeometry {
        NookCompactGeometry(
            form: nook.layoutForm,
            notchSize: nook.notchSize,
            menubarHeight: nook.menubarHeight,
            leadingWidth: nook.disableCompactLeading ? 0 : compactLeadingWidth,
            trailingWidth: nook.disableCompactTrailing ? 0 : compactTrailingWidth
        )
    }

    private var compactActivityAction: NookCompactActivityAction {
        NookCompactActivityAction { [weak nook] in
            nook?.noteCompactActivity()
        }
    }

    private var compactHoverMeasurementsReady: Bool {
        NookCompactHoverAdmission.measurementsReady(
            leadingSlotDisabled: nook.disableCompactLeading,
            leadingSlotMeasured: hasMeasuredCompactLeading,
            trailingSlotDisabled: nook.disableCompactTrailing,
            trailingSlotMeasured: hasMeasuredCompactTrailing
        )
    }

    /// Consume only a real `.active` event that arrived before the first slot measurement.
    /// Later width changes keep readiness `true`, so they cannot synthesize an expand.
    private func reconcilePendingCompactHover(from wasReady: Bool, to isReady: Bool) {
        guard
            let location = compactHoverAdmission.measurementsChanged(
                from: wasReady,
                to: isReady
            )
        else { return }
        guard nook.state == .compact else { return }
        admitHover(at: location)
    }

    private func admitHover(at panelLocation: CGPoint) {
        let isInsideInteractionRegion: Bool
        switch nook.state {
            case .compact:
                isInsideInteractionRegion =
                    compactHoverMeasurementsReady
                    && compactGeometry.contains(panelLocation, in: nook.panelSize)
            case .expanded:
                isInsideInteractionRegion = true
            case .hidden:
                isInsideInteractionRegion = false
        }
        nook.updateHoverState(true, withinInteractionRegion: isInsideInteractionRegion)
    }

    private func notchBackdrop() -> some View {
        NookBackdropView(backdrop: nook.backdrop, shape: notchShape)
    }

    private func notchContent() -> some View {
        ZStack {
            compactContent()
                .fixedSize()
                .offset(x: nook.state == .compact ? 0 : compactXOffset)
                .frame(
                    // Notch mode reserves the notch width while expanded so the
                    // collapsed slots line up; a floating pill is content-driven.
                    width: (nook.state == .compact || isFloating) ? nil : nook.notchSize.width,
                    height: (nook.state == .compact && nook.isHovering) ? nook.menubarHeight : nook.notchSize.height
                )

            expandedContent()
                .fixedSize()
                .frame(
                    maxWidth: nook.state == .expanded ? nil : 0,
                    maxHeight: nook.state == .expanded ? nil : 0
                )
                .offset(x: nook.state == .compact ? -compactXOffset : 0)
        }
        .padding(
            .horizontal,
            nook.state == .compact ? compactGeometry.horizontalPadding : topCornerRadius
        )
        .fixedSize()
        .frame(minWidth: minWidth, minHeight: nook.notchSize.height)
    }

    private func compactContent() -> some View {
        HStack(spacing: 0) {
            if nook.state == .compact, !nook.disableCompactLeading {
                nook.compactLeadingContent
                    .safeAreaInset(edge: .leading, spacing: 0) {
                        Color.clear.frame(width: NookCompactGeometry.slotHorizontalInset)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: NookCompactGeometry.slotTopInset)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: NookCompactGeometry.slotBottomInset)
                    }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) {
                        guard nook.state == .compact, $0.isFinite, $0 >= 0 else { return }
                        compactLeadingWidth = $0
                        hasMeasuredCompactLeading = true
                    }
                    .transition(
                        .blur(intensity: 6).combined(with: .scale(x: 0, anchor: .trailing)).combined(with: .opacity)
                    )
            }

            // Notch mode: a gap exactly the notch width, so the leading/trailing slots
            // straddle the physical notch. Floating mode: no notch - just a small gap
            // keeping the two slots from touching inside the pill.
            Spacer()
                .frame(width: compactGeometry.gapWidth)

            if nook.state == .compact, !nook.disableCompactTrailing {
                nook.compactTrailingContent
                    .safeAreaInset(edge: .trailing, spacing: 0) {
                        Color.clear.frame(width: NookCompactGeometry.slotHorizontalInset)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: NookCompactGeometry.slotTopInset)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: NookCompactGeometry.slotBottomInset)
                    }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) {
                        guard nook.state == .compact, $0.isFinite, $0 >= 0 else { return }
                        compactTrailingWidth = $0
                        hasMeasuredCompactTrailing = true
                    }
                    .transition(
                        .blur(intensity: 6).combined(with: .scale(x: 0, anchor: .leading)).combined(with: .opacity)
                    )
            }
        }
        .opacity(nook.compactContentOpacity)
        .frame(height: nook.notchSize.height)
        // `disableCompactLeading/Trailing` are construction-time `let`s on `Nook` -
        // they cannot change at runtime, so no `.onChange` reconciliation is needed.
        // Width values retain their last valid measurement while the slot views disappear.
        // `onGeometryChange` refreshes them when the width actually changes; preserving
        // readiness avoids stranding hover when an interrupted transition reuses the view.
    }

    private func expandedContent() -> some View {
        HStack(spacing: 0) {
            if nook.state == .expanded {
                nook.expandedContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.nookContentInsets, contentInsets)
                    .transition(
                        .blur(intensity: 6).combined(with: .scale(y: 0.72, anchor: .top)).combined(with: .opacity)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: expandedContentInsets.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: expandedContentInsets.bottom) }
        .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: expandedContentInsets.leading) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: expandedContentInsets.trailing) }
        .background {
            if let ambientColor {
                NookAmbientColorBackground(color: ambientColor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: ambientColor)
        .onPreferenceChange(NookAmbientColorPreferenceKey.self) { ambientColor = $0 }
        .frame(minWidth: isFloating ? 0 : nook.notchSize.width)
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            guard nook.state == .expanded, size != trackedExpandedSize else { return }
            trackedExpandedSize = size
            nook.noteExpandedContentSizeChange()
        }
    }
}
