// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Top-level Settings surface, rendered when the expanded nook is in `.settings` mode.
/// Composes the per-section groups (Appearance, Display, Shortcut & nook, Data, About)
/// into one scrolling stack. Each section's content is its own file under `Views/Settings/`.
///
/// Layout is deliberately flat: section label, then content, on one shared left margin
/// (aligned with the top bar via `\.nookContentInsets`), separated by whitespace only,
/// no card fills, no rules.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    /// Host-supplied sections rendered below the framework groups and above About.
    let hostSections: [NookSettingsSection]
    let configuration: NookBuiltInSettingsConfiguration
    let onToggleKeepOpen: () -> Void
    let onResetAllSettings: () -> Void

    @Environment(\.nookChromeMetrics) private var metrics

    /// Curve-derived leading/trailing insets from the chrome. Matching them here aligns the
    /// section labels and rows with the top bar's leading cluster on a notched display.
    @Environment(\.nookContentInsets) private var contentInsets

    /// Which sections are expanded. In-memory for the lifetime of this Settings view.
    @State private var expandedSections: Set<String>

    /// Caps Settings from the same resolved target screen the coordinator gives the nook.
    /// This keeps a shorter secondary display from inheriting the main display's viewport.
    private var settingsScrollMaxHeight: CGFloat {
        guard let screen = NookScreenLocator.screen(matching: appState.displayPreference) else {
            return SettingsViewportSizing.fallbackMaximumHeight
        }
        return SettingsViewportSizing.maximumHeight(
            targetScreenVisibleHeight: screen.visibleFrame.height
        )
    }

    init(
        appState: AppState,
        hostSections: [NookSettingsSection],
        configuration: NookBuiltInSettingsConfiguration,
        onToggleKeepOpen: @escaping () -> Void,
        onResetAllSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.hostSections = hostSections
        self.configuration = configuration
        self.onToggleKeepOpen = onToggleKeepOpen
        self.onResetAllSettings = onResetAllSettings
        _expandedSections = State(
            initialValue: configuration.resolvedInitiallyExpandedGroupIDs(
                hostSections: hostSections
            )
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: metrics.settingsSectionSpacing) {
                ForEach(configuration.resolvedGroups(hostSections: hostSections)) { group in
                    section(id: group.id, title: group.title) {
                        SettingsGroupContent(
                            appState: appState,
                            group: group,
                            hostSections: hostSections,
                            configuration: configuration,
                            onToggleKeepOpen: onToggleKeepOpen,
                            onResetAllSettings: onResetAllSettings
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, metrics.settingsContentBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: settingsScrollMaxHeight, alignment: .leading)
    }

    /// A collapsible section bound to ``expandedSections``: a disclosure header, and - when
    /// open - the content indented under a connector hairline.
    @ViewBuilder
    private func section<Content: View>(
        id: String,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SettingsDisclosureSection(
            title: title,
            isExpanded: Binding(
                get: { expandedSections.contains(id) },
                set: { open in
                    if open { expandedSections.insert(id) } else { expandedSections.remove(id) }
                }
            ),
            content: content
        )
    }
}

/// A settings section with a tap-to-toggle disclosure header and a left connector hairline
/// tying the indented content back to the header.
private struct SettingsDisclosureSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    var body: some View {
        let iconGutter = metrics.settingsDisclosureGutter
        VStack(alignment: .leading, spacing: metrics.settingsBlockSpacing) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: metrics.settingsInlineSpacing) {
                    Image(systemName: "chevron.right")
                        .font(typography.settingsDisclosureChevron)
                        .foregroundStyle(theme.quaternaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: iconGutter)
                    SettingsSectionLabel(title)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(alignment: .top, spacing: metrics.settingsGroupSpacing) {
                    // Connector: a thin vertical rule that fills the content height, tying the
                    // indented items back to the header. Centered under the chevron gutter.
                    RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                        .fill(theme.subtleStroke.opacity(metrics.settingsConnectorOpacity))
                        .frame(width: metrics.settingsConnectorWidth)

                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, (iconGutter - metrics.settingsConnectorWidth) / 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
