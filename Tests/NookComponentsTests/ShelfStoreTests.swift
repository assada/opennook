// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookComponents

final class ShelfStoreTests: XCTestCase {
    /// Writes a throwaway file into the temp directory and returns its URL.
    private func makeTempFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nook-shelf-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        try Data("nook".utf8).write(to: url)
        return url
    }

    /// A store backed by a unique, isolated `UserDefaults` suite so tests don't collide.
    private func freshStore() -> (store: ShelfStore, defaults: UserDefaults, key: String) {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        return (ShelfStore(persistenceKey: key, defaults: defaults), defaults, key)
    }

    func testAcceptAddsResolvableItem() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.accept([url]))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(
            store.items.first?.resolveURL()?.standardizedFileURL,
            url.standardizedFileURL
        )
    }

    func testAcceptSkipsDuplicates() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.accept([url]))
        XCTAssertFalse(store.accept([url]), "the same file should not be shelved twice")
        XCTAssertEqual(store.items.count, 1)
    }

    func testRemoveAndClear() throws {
        let (store, _, _) = freshStore()
        let first = try makeTempFile()
        let second = try makeTempFile()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        store.accept([first, second])
        XCTAssertEqual(store.items.count, 2)

        store.remove(store.items[0])
        XCTAssertEqual(store.items.count, 1)

        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistenceRoundTrip() throws {
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"

        let first = ShelfStore(persistenceKey: key, defaults: defaults)
        first.accept([url])

        // A second store over the same defaults must reload the shelved file.
        let second = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.resolveURL()?.standardizedFileURL, url.standardizedFileURL)
    }

    func testPurgeMissingDropsDeletedFile() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()

        store.accept([url])
        XCTAssertEqual(store.items.count, 1)

        try FileManager.default.removeItem(at: url)
        store.purgeMissing()
        XCTAssertTrue(store.items.isEmpty, "an item whose file is gone should be purged")
    }
}
