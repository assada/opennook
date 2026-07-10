// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

extension NookBuiltInSettingsConfiguration {
    func resolvedGroups(hostSections: [NookSettingsSection]) -> [NookSettingsGroup] {
        if let groups {
            return groups
        }

        var result: [NookSettingsGroup] = []
        appendGroup(
            id: "Appearance",
            title: "Appearance",
            items: [.theme, .surface, .layout, .accent, .backdropStrength],
            to: &result
        )
        appendGroup(id: "Display", title: "Display", items: [.display], to: &result)
        appendGroup(
            id: "Shortcut & nook",
            title: "Shortcut & nook",
            items: [.globalShortcut, .stayExpanded, .hapticFeedback],
            to: &result
        )
        appendGroup(
            id: "Data",
            title: "Data",
            items: [.statusBannerPreview, .resetAllSettings],
            to: &result
        )
        result.append(contentsOf: hostSections.map { section in
            NookSettingsGroup(
                id: section.id,
                title: section.title,
                items: [.hostSection(section.id)]
            )
        })
        appendGroup(id: "About", title: "About", items: [.about], to: &result)
        return result
    }

    private func appendGroup(
        id: String,
        title: String,
        items: [NookBuiltInSettingsItem],
        to groups: inout [NookSettingsGroup]
    ) {
        let visibleItems = items.filter(shows)
        guard !visibleItems.isEmpty else { return }
        groups.append(
            NookSettingsGroup(
                id: id,
                title: title,
                items: visibleItems.map(NookSettingsGroupItem.builtIn)
            )
        )
    }
}
