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

    /// Drops items whose bookmark no longer resolves to an existing file. Called once on
    /// `init`; a host can call it again (e.g. when the shelf surface appears).
    public func purgeMissing() {
        let before = items.count
        items.removeAll { item in
            guard let url = item.resolveURL() else { return true }
            return !FileManager.default.fileExists(atPath: url.path)
        }
        if items.count != before { persist() }
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
