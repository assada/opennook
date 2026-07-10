// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

/// A configurable item in OpenNook's framework-owned Settings surface.
///
/// Hosts hide only the controls that do not make sense for their product while retaining
/// OpenNook's canonical layout, interaction states, persistence, and accessibility behavior.
public enum NookBuiltInSettingsItem: String, CaseIterable, Hashable, Sendable {
    case theme
    case surface
    case layout
    case accent
    case backdropStrength
    case display
    case globalShortcut
    case stayExpanded
    case hapticFeedback
    case statusBannerPreview
    case resetAllSettings
    case about
}

/// One reusable piece of a host-composed Settings group.
///
/// Built-in items keep OpenNook's native controls and behavior. Host sections are
/// referenced by the stable id supplied to ``NookConfiguration/addSettingsSection``.
public enum NookSettingsGroupItem: Hashable, Sendable {
    case builtIn(NookBuiltInSettingsItem)
    case hostSection(String)
}

/// An ordered disclosure group in OpenNook's framework-owned Settings surface.
///
/// Hosts use groups to arrange framework controls and their own sections by user task
/// without replacing the canonical Settings screen.
public struct NookSettingsGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let items: [NookSettingsGroupItem]

    public init(
        id: String,
        title: String,
        items: [NookSettingsGroupItem]
    ) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// Host customization for the framework-owned Settings surface.
///
/// This is intentionally additive to ``NookConfiguration/settingsSections``. Use
/// `hiddenItems` for small product-specific omissions and host sections for additional
/// controls. Use ``NookConfiguration/setSettings(_:)`` only when replacing the complete
/// Settings experience is truly required.
public struct NookBuiltInSettingsConfiguration: Sendable {
    /// Controls omitted from the built-in surface. Empty preserves the complete default UI.
    public var hiddenItems: Set<NookBuiltInSettingsItem>

    /// Optional task-oriented Settings composition. `nil` preserves OpenNook's standard
    /// Appearance, Display, Shortcut & nook, Data, host-section, About order.
    public var groups: [NookSettingsGroup]?

    /// Disclosure ids open when Settings is first constructed. `nil` preserves the
    /// framework default (`Appearance`); an empty set starts with every group collapsed.
    public var initiallyExpandedGroupIDs: Set<String>?

    /// Runs after OpenNook resets its own appearance, display, and shortcut preferences.
    /// Hosts use this to reset their injected product settings in the same user action.
    public var onResetAllSettings: (@Sendable @MainActor () -> Void)?

    public init(
        hiddenItems: Set<NookBuiltInSettingsItem> = [],
        groups: [NookSettingsGroup]? = nil,
        initiallyExpandedGroupIDs: Set<String>? = nil,
        onResetAllSettings: (@Sendable @MainActor () -> Void)? = nil
    ) {
        self.hiddenItems = hiddenItems
        self.groups = groups
        self.initiallyExpandedGroupIDs = initiallyExpandedGroupIDs
        self.onResetAllSettings = onResetAllSettings
    }

    public static let `default` = NookBuiltInSettingsConfiguration()

    func shows(_ item: NookBuiltInSettingsItem) -> Bool {
        !hiddenItems.contains(item)
    }

    var showsAppearanceSection: Bool {
        [.theme, .surface, .layout, .accent, .backdropStrength].contains(where: shows)
    }

    var showsShortcutSection: Bool {
        [.globalShortcut, .stayExpanded, .hapticFeedback].contains(where: shows)
    }

    var showsDataSection: Bool {
        [.statusBannerPreview, .resetAllSettings].contains(where: shows)
    }
}
