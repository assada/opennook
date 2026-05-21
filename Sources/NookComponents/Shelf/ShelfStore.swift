// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Observable model backing the notch file shelf.
///
/// A host owns one `ShelfStore`, renders it with ``NookShelfView``, and wires
/// ``accept(_:)`` into `NookConfiguration.onFileDrop`. The store persists itself to
/// `UserDefaults` (as encoded ``ShelfItem`` bookmarks) and reloads on the next launch,
/// dropping any items whose files have since disappeared.
///
/// Like most `ObservableObject` view models it is intended for main-thread use — file
/// drops and SwiftUI interactions both arrive there.
public final class ShelfStore: ObservableObject {
    /// Shelved files, oldest first.
    @Published public private(set) var items: [ShelfItem] = []

    private let persistenceKey: String
    private let defaults: UserDefaults

    /// - Parameters:
    ///   - persistenceKey: `UserDefaults` key the encoded shelf is stored under.
    ///   - defaults: the `UserDefaults` instance — injectable for tests.
    public init(persistenceKey: String = "nook.shelf.items", defaults: UserDefaults = .standard) {
        self.persistenceKey = persistenceKey
        self.defaults = defaults
        load()
        healStaleBookmarks()
        purgeMissing()
    }

    /// Adds files to the shelf, skipping any already present (compared by resolved path).
    /// Drop-in for `NookConfiguration.onFileDrop` — returns `true` if at least one file
    /// was added, which keeps the nook expanded so the shelf is visible.
    @discardableResult
    public func accept(_ urls: [URL]) -> Bool {
        let existing = Set(items.compactMap { $0.resolveURL()?.standardizedFileURL.path })
        let added = urls
            .filter { !existing.contains($0.standardizedFileURL.path) }
            .compactMap { ShelfItem.make(from: $0) }
        guard !added.isEmpty else { return false }
        items.append(contentsOf: added)
        persist()
        return true
    }

    public func remove(_ item: ShelfItem) {
        remove(id: item.id)
    }

    public func remove(id: ShelfItem.ID) {
        let before = items.count
        items.removeAll { $0.id == id }
        if items.count != before { persist() }
    }

    public func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        persist()
    }

    /// Drops items whose file is genuinely gone. Called once on `init`; a host can call
    /// it again (e.g. when the shelf surface appears).
    ///
    /// A resolution failure is **ambiguous** — under the App Sandbox a lost grant looks
    /// identical to a deleted file. So purging is conservative: if *every* item fails to
    /// resolve, that's treated as a systemic access failure and nothing is dropped (this
    /// is what stops a sandboxed host silently wiping the whole shelf). Individual
    /// failures are only purged when at least one sibling still resolves — i.e. access
    /// is working and that one file really is gone.
    public func purgeMissing() {
        guard !items.isEmpty else { return }
        let resolutions = items.map { ($0, $0.resolveURL()) }
        guard resolutions.contains(where: { $0.1 != nil }) else { return }

        let before = items.count
        items = resolutions.compactMap { $0.1 == nil ? nil : $0.0 }
        if items.count != before { persist() }
    }

    /// Re-captures any bookmark that resolved but reported itself stale (file moved
    /// across volumes, OS bookmark-format migration). Apple's contract is to re-bookmark
    /// from the resolved URL; left unhealed, a stale bookmark eventually stops resolving.
    private func healStaleBookmarks() {
        var changed = false
        items = items.map { item in
            guard let resolution = item.resolved(), resolution.isStale,
                  let refreshed = item.refreshedBookmark() else {
                return item
            }
            changed = true
            return refreshed
        }
        if changed { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
