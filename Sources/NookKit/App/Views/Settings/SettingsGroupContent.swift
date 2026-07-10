// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

import NookSurface
import SwiftUI

/// Renders one ordered group from reusable framework controls and host section content.
struct SettingsGroupContent: View {
    @ObservedObject var appState: AppState
    let group: NookSettingsGroup
    let hostSections: [NookSettingsSection]
    let configuration: NookBuiltInSettingsConfiguration
    let onToggleKeepOpen: () -> Void
    let onResetAllSettings: () -> Void

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsGroupSpacing) {
            ForEach(group.items, id: \.self) { item in
                groupItem(item)
            }
        }
    }

    @ViewBuilder
    private func groupItem(_ item: NookSettingsGroupItem) -> some View {
        switch item {
        case let .builtIn(item) where configuration.shows(item):
            builtInItem(item)
        case let .hostSection(id):
            if let section = hostSections.first(where: { $0.id == id }) {
                section.content()
            }
        case .builtIn:
            EmptyView()
        }
    }

    @ViewBuilder
    private func builtInItem(_ item: NookBuiltInSettingsItem) -> some View {
        switch item {
        case .theme, .surface, .layout, .accent, .backdropStrength:
            NookAppearanceSettingsSection(
                appState: appState,
                configuration: configurationShowingOnly(item)
            )
        case .display:
            DisplaySettingsSection(appState: appState)
        case .globalShortcut:
            SettingsShortcutRow(appState: appState)
            if !appState.hotkeyRegistrationFailures.keys
                .filter({ $0 != NookHotkeyIDs.toggle }).isEmpty {
                SettingsHotkeyFailureRow(appState: appState)
            }
        case .stayExpanded:
            SettingActionLine(
                icon: appState.keepNookOpen ? "pin.fill" : "pin",
                title: "Keep open",
                detail: appState.keepNookOpen
                    ? "On — stays open after the pointer leaves"
                    : "Off — closes when the pointer leaves",
                accent: theme.accent,
                action: onToggleKeepOpen
            )
        case .hapticFeedback:
            SettingActionLine(
                icon: appState.appearancePreferences.hapticFeedbackEnabled
                    ? "hand.tap.fill" : "hand.tap",
                title: "Haptic feedback",
                detail: appState.appearancePreferences.hapticFeedbackEnabled
                    ? "On — trackpad pulse on confirmation"
                    : "Off — silent confirmation",
                accent: theme.accent,
                action: toggleHapticFeedback
            )
        case .statusBannerPreview:
            SettingsDataCommandRow(
                title: "Preview status banner",
                subtitle: "Shows the transient message channel under the top bar",
                icon: "text.bubble",
                style: .standard,
                action: previewStatusBanner
            )
        case .resetAllSettings:
            SettingsDataCommandRow(
                title: "Reset All Settings",
                subtitle: "Appearance, display, shortcuts, and host settings",
                icon: "arrow.counterclockwise",
                style: .standard,
                action: performResetAllSettings
            )
        case .about:
            SettingsAboutCard()
        }
    }

    private func configurationShowingOnly(
        _ item: NookBuiltInSettingsItem
    ) -> NookBuiltInSettingsConfiguration {
        NookBuiltInSettingsConfiguration(
            hiddenItems: Set(NookBuiltInSettingsItem.allCases).subtracting([item])
        )
    }

    private func toggleHapticFeedback() {
        var preferences = appState.appearancePreferences
        preferences.hapticFeedbackEnabled.toggle()
        appState.replaceAppearancePreferences(preferences)
        NookHaptics.confirm(enabled: preferences.hapticFeedbackEnabled)
    }

    private func previewStatusBanner() {
        appState.errorMessage = "Something went wrong — try again."
        appState.showHome()
    }

    private func performResetAllSettings() {
        onResetAllSettings()
        configuration.onResetAllSettings?()
    }
}
