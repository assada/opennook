// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Settings row for the global show/hide hotkey. Tap the shortcut to record a new one:
/// the next modifier + key combination is captured, persisted via `AppState`, and
/// re-registered live by `AppCoordinator`. Escape cancels.
struct SettingsShortcutRow: View {
    @ObservedObject var appState: AppState
    @StateObject private var recorder: NookHotkeyRecorder

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics
    @Environment(\.nookHostBranding) private var branding

    init(appState: AppState) {
        self.appState = appState
        _recorder = StateObject(wrappedValue: NookHotkeyRecorder(appState: appState))
    }

    var body: some View {
        HStack(alignment: .center, spacing: metrics.settingsGroupSpacing) {
            Image(systemName: "keyboard")
                .font(typography.settingsEmphasis)
                .foregroundStyle(theme.headerInactiveIcon)
                .frame(width: metrics.settingsIconWidth)

            VStack(alignment: .leading, spacing: metrics.settingsTextSpacing) {
                Text("Show \(branding.hostName)")
                    .font(typography.settingsRowTitle)
                    .foregroundStyle(theme.primaryLabel.opacity(metrics.settingsTitleEmphasisOpacity))
                if let failure = appState.globalHotkeyRegistrationFailure {
                    Text(failure.message)
                        .font(typography.settingsHint)
                        .foregroundStyle(Color.orange)
                } else {
                    Text(recorder.isRecording ? "Press a shortcut — Esc to cancel" : "Global shortcut — click to change")
                        .font(typography.settingsHint)
                        .foregroundStyle(theme.tertiaryLabel)
                }
            }

            Spacer(minLength: 8)

            Button(action: recorder.toggle) {
                if recorder.isRecording {
                    Text("Listening…")
                        .font(typography.settingsFieldLabel)
                        .foregroundStyle(theme.primaryLabel.opacity(metrics.settingsRecordingLabelOpacity))
                        .padding(.horizontal, metrics.settingsRecordingHorizontalPadding)
                        .frame(minHeight: metrics.settingsRecordingMinHeight)
                        .background(theme.subtleFill.opacity(metrics.settingsRecordingFillOpacity), in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                theme.accent.opacity(metrics.settingsRecordingStrokeOpacity),
                                lineWidth: metrics.settingsRecordingStrokeWidth
                            )
                        )
                } else {
                    HStack(spacing: metrics.shortcutKeyCapSpacing) {
                        ForEach(Array(appState.hotkey.displaySymbols.enumerated()), id: \.offset) { _, symbol in
                            ShortcutKeySquircle(symbol: symbol)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, metrics.settingsRowVerticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Show \(branding.hostName) shortcut, "
                + "currently \(appState.hotkey.displaySymbols.joined(separator: " "))"
        )
        .accessibilityHint("Activates to record a new shortcut")
        .onDisappear { recorder.stop() }
    }
}

/// Surfaces hotkey-registration failures for the host-configured shortcuts - the
/// module direct-jump keys and the module-cycle key. The user-rebindable show/hide
/// shortcut reports its own failure inline in ``SettingsShortcutRow``; this row covers
/// the static shortcuts, which would otherwise fail silently. Renders nothing when
/// every static shortcut registered successfully.
struct SettingsHotkeyFailureRow: View {
    @ObservedObject var appState: AppState

    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    /// Failures for every shortcut except the show/hide toggle, sorted for stable order.
    private var staticFailures: [HotkeyRegistrationFailure] {
        appState.hotkeyRegistrationFailures
            .filter { $0.key != NookHotkeyIDs.toggle }
            .values
            .sorted { $0.shortcutName < $1.shortcutName }
    }

    var body: some View {
        if !staticFailures.isEmpty {
            VStack(alignment: .leading, spacing: metrics.settingsFailureRowSpacing) {
                ForEach(staticFailures, id: \.shortcutName) { failure in
                    HStack(alignment: .center, spacing: metrics.settingsGroupSpacing) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(typography.settingsEmphasis)
                            .foregroundStyle(Color.orange)
                            .frame(width: metrics.settingsIconWidth)
                        VStack(alignment: .leading, spacing: metrics.settingsTextSpacing) {
                            Text(failure.shortcutName)
                                .font(typography.settingsRowTitle)
                            Text(failure.message)
                                .font(typography.settingsHint)
                                .foregroundStyle(Color.orange)
                        }
                        Spacer(minLength: 8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(failure.shortcutName) shortcut unavailable: \(failure.message)")
                }
            }
            .padding(.vertical, metrics.settingsRowVerticalPadding)
        }
    }
}
