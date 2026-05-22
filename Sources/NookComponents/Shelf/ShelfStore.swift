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
/// `@MainActor`-isolated: the `@Published` `items` drives SwiftUI, and every mutation
/// path arrives on the main actor — file drops are delivered by the (main-actor) `Nook`
/// surface, and SwiftUI interactions are main-actor by definition. This matches the
/// concurrency contract of `NookActivityQueue`.
@MainActor
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
        loadAndReconcile()
    }

    /// Adds files to the shelf, skipping any already present (compared by resolved path).
    /// Drop-in for `NookConfiguration.onFileDrop` — returns `true` if at least one file
    /// was added, which keeps the nook expanded so the shelf is visible.
    @discardableResult
    public func accept(_ urls: [URL]) -> Bool {
        // Dedup is a *path-level* comparison, so `resolveURL()` (no security scope) is
        // the right call here — and is deliberately not wrapped in `withResolvedURL`.
        // Per `ShelfItem`'s contract, security-scoped access is only needed to touch a
        // file's *contents*; resolving a bookmark to a URL for comparison does not need
        // it. Bracketing here would start/stop scoped access for no read — pure overhead.
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

    /// Drops items whose file is genuinely gone. Called via ``loadAndReconcile()`` on
    /// `init`; a host can call this again (e.g. when the shelf surface appears).
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

    /// Loads the persisted shelf and reconciles it in a **single pass** over every item,
    /// resolving each bookmark exactly once. For each item that pass does two things:
    ///
    /// - **Heal:** a bookmark that resolves but reports itself stale (file moved across
    ///   volumes, OS bookmark-format migration) is re-captured from the resolved URL.
    ///   Apple's contract is to re-bookmark from there; left unhealed it eventually
    ///   stops resolving.
    /// - **Purge:** an item whose bookmark fails to resolve is a *candidate* for removal,
    ///   but only when at least one sibling still resolves. A total resolution failure is
    ///   indistinguishable from a sandboxed host losing its access grant, so in that case
    ///   nothing is dropped — the same conservative rule as ``purgeMissing()``.
    ///
    /// This is the consolidation of what used to be three separate full passes
    /// (`load` + `healStaleBookmarks` + `purgeMissing`) and is behaviour-preserving.
    private func loadAndReconcile() {
        guard let data = defaults.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            return
        }

        // One resolution per item, reused for both the heal and the purge decision.
        let reconciled: [(item: ShelfItem, resolved: Bool, healed: Bool)] = decoded.map { item in
            guard let resolution = item.resolved() else {
                return (item, false, false)
            }
            if resolution.isStale, let fresh = item.reBookmarked(from: resolution.url) {
                return (fresh, true, true)
            }
            return (item, true, false)
        }

        // Purge individual misses only when access is clearly working (a sibling
        // resolved); a systemic failure preserves the whole shelf.
        let anyResolved = reconciled.contains { $0.resolved }
        let kept = reconciled.filter { anyResolved ? $0.resolved : true }

        items = kept.map(\.item)

        let droppedAny = kept.count != decoded.count
        let healedAny = kept.contains { $0.healed }
        if droppedAny || healedAny { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
