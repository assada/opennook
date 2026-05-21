// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation
import UniformTypeIdentifiers

/// One file parked on the notch shelf.
///
/// Persists a **bookmark**, not a raw path, so a shelved file survives being moved or
/// renamed between launches. `resolveURL()` turns the bookmark back into a live URL;
/// it returns `nil` once the file is gone (see ``ShelfStore/purgeMissing()``).
///
/// The framework demo app is not sandboxed, so a plain (non-security-scoped) bookmark
/// is sufficient. A sandboxed host would need security-scoped bookmarks — the `bookmark`
/// field is deliberately opaque `Data` so that strategy can change without an API break.
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// File name without extension — what the chip label shows.
    public let displayName: String
    public let fileExtension: String
    public let addedAt: Date
    /// Bookmark data resolving back to the file. Opaque by design.
    public let bookmark: Data
    /// `UTType` identifier, for the outbound drag pasteboard.
    public let typeIdentifier: String

    /// Builds an item from a file URL, capturing a bookmark. Returns `nil` if the URL
    /// can't be bookmarked (e.g. it doesn't exist).
    public static func make(from url: URL) -> ShelfItem? {
        guard let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }
        let type = UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.data.identifier
        return ShelfItem(
            id: UUID(),
            displayName: url.deletingPathExtension().lastPathComponent,
            fileExtension: url.pathExtension,
            addedAt: Date(),
            bookmark: bookmark,
            typeIdentifier: type
        )
    }

    /// Resolves the bookmark to a current URL, or `nil` if the file can no longer be found.
    public func resolveURL() -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
