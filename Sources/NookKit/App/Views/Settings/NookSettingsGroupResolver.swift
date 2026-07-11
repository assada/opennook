// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin

extension NookBuiltInSettingsConfiguration {
    /// Resolves the disclosure state for a newly-created Settings surface. An explicit
    /// set, including an empty one, is authoritative. Otherwise open the first group that
    /// actually declares content instead of assuming the default `Appearance` group is
    /// present after host filtering/composition.
    func resolvedInitiallyExpandedGroupIDs(
        hostSections: [NookSettingsSection]
    ) -> Set<String> {
        if let initiallyExpandedGroupIDs {
            return initiallyExpandedGroupIDs
        }

        guard
            let firstGroup = resolvedGroups(hostSections: hostSections)
                .first(where: { groupHasVisibleContent($0, hostSections: hostSections) })
        else {
            return []
        }
        return [firstGroup.id]
    }

    private func groupHasVisibleContent(
        _ group: NookSettingsGroup,
        hostSections: [NookSettingsSection]
    ) -> Bool {
        group.items.contains { item in
            switch item {
                case .builtIn(let item):
                    shows(item)
                case .hostSection(let id):
                    hostSections.contains(where: { $0.id == id })
            }
        }
    }

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
        result.append(
            contentsOf: hostSections.map { section in
                NookSettingsGroup(
                    id: section.id,
                    title: section.title,
                    items: [.hostSection(section.id)]
                )
            }
        )
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
