//  DraftStoreTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

final class DraftStoreTests: XCTestCase {

    private var rootDirectory: URL!
    private var store: DraftStore!

    override func setUp() {
        super.setUp()
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DraftStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = DraftStore(rootDirectory: rootDirectory)
    }

    override func tearDown() {
        store.deleteAllDrafts()
        store = nil
        rootDirectory = nil
        super.tearDown()
    }

    private func makeDraft(_ payload: String) -> StubDraft {
        StubDraft(storePath: "replies/123", payload: payload)
    }

    func testWaitingSaveWritesFileBeforeReturning() {
        store.saveDraft(makeDraft("hello"), waitUntilFinished: true)

        let url = rootDirectory.appendingPathComponent("replies/123/Draft.dat")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testLoadImmediatelyAfterBackgroundSaveSeesThatSave() {
        store.saveDraft(makeDraft("first"))
        store.saveDraft(makeDraft("second"))

        let loaded = store.loadDraft("replies/123") as? StubDraft
        XCTAssertEqual(loaded?.payload, "second")
    }

    func testDeleteAfterBackgroundSaveWins() {
        let draft = makeDraft("doomed")
        store.saveDraft(draft)
        store.deleteDraft(draft)

        XCTAssertNil(store.loadDraft("replies/123"))
    }
}

/// A minimal draft for exercising the store without Core Data.
@objc(DraftStoreTestsStubDraft)
private final class StubDraft: NSObject, StorableDraft {
    let storePath: String
    let payload: String

    init(storePath: String, payload: String) {
        self.storePath = storePath
        self.payload = payload
    }

    required init?(coder: NSCoder) {
        guard let storePath = coder.decodeObject(forKey: "storePath") as? String,
              let payload = coder.decodeObject(forKey: "payload") as? String
        else { return nil }
        self.storePath = storePath
        self.payload = payload
    }

    func encode(with coder: NSCoder) {
        coder.encode(storePath, forKey: "storePath")
        coder.encode(payload, forKey: "payload")
    }
}
