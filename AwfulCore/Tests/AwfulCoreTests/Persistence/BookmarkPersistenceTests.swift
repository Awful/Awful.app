//  BookmarkPersistenceTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import XCTest

final class BookmarkPersistenceTests: XCTestCase {

    private var context: NSManagedObjectContext!
    /// The app installs one of these on every context so that saves fill in the required lastModifiedDate. Installed per test, after any records whose lastModifiedDate the test sets by hand have been saved.
    private var lastModifiedObserver: LastModifiedContextObserver?

    override class func setUp() {
        super.setUp()
        testInit()
    }

    override func setUp() {
        super.setUp()
        context = makeInMemoryStoreContext()
    }

    override func tearDown() {
        lastModifiedObserver = nil
        context = nil
        super.tearDown()
    }

    /// A thread ID that appears in the bookmarkthreads.html fixture.
    private let fixtureThreadID = "3391052"

    private func insertBookmarkedThread(threadID: String, title: String, lastModified: Date) -> AwfulThread {
        let thread = AwfulThread.insert(into: context)
        thread.threadID = threadID
        thread.title = title
        thread.bookmarked = true
        thread.bookmarkListPage = 1
        thread.lastModifiedDate = lastModified as NSDate
        return thread
    }

    private func bookmarkedThreads() -> [AwfulThread] {
        AwfulThread.fetch(in: context) {
            $0.predicate = .init("\(\AwfulThread.bookmarked) = YES AND \(\AwfulThread.bookmarkListPage) > 0")
        }
    }

    func testDuplicateThreadRecordsOnlyOneRemainsInBookmarksList() throws {
        let older = insertBookmarkedThread(threadID: fixtureThreadID, title: "Older copy", lastModified: Date(timeIntervalSinceNow: -3600))
        let newer = insertBookmarkedThread(threadID: fixtureThreadID, title: "Newer copy", lastModified: Date())
        try context.save()
        lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: context)

        let result = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: "bookmarkthreads")
        let threads = try result.upsert(into: context)
        AwfulThread.clearStaleBookmarks(notIn: threads, fromPage: 1, in: context)
        try context.save()

        XCTAssertEqual(threads.filter { $0.threadID == fixtureThreadID }.count, 1)
        XCTAssertTrue(threads.contains(newer), "most recently modified duplicate should be the one updated")
        XCTAssertFalse(threads.contains(older))

        let listed = bookmarkedThreads()
        XCTAssertEqual(listed.filter { $0.threadID == fixtureThreadID }.count, 1)
        XCTAssertEqual(listed.count, result.threads.count)
        XCTAssertEqual(older.bookmarkListPage, 0)
        XCTAssertEqual(newer.bookmarkListPage, 1)
    }

    func testStaleBookmarkCleanupKeepsEarlierPages() throws {
        let page1 = insertBookmarkedThread(threadID: "1", title: "page 1", lastModified: Date())
        let page2 = insertBookmarkedThread(threadID: "2", title: "page 2", lastModified: Date())
        page2.bookmarkListPage = 2
        try context.save()

        AwfulThread.clearStaleBookmarks(notIn: [], fromPage: 2, in: context)

        XCTAssertEqual(page1.bookmarkListPage, 1)
        XCTAssertEqual(page2.bookmarkListPage, 0)
    }

    func testPersistedObjectForKeySavesNewlyInsertedObject() throws {
        lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: context)
        let thread = AwfulThread.persistedObjectForKey(objectKey: ThreadKey(threadID: "12345"), in: context)
        XCTAssertFalse(thread.isInserted)
        XCTAssertFalse(context.hasChanges)

        let again = AwfulThread.persistedObjectForKey(objectKey: ThreadKey(threadID: "12345"), in: context)
        XCTAssertEqual(again, thread)
        XCTAssertEqual(AwfulThread.fetch(in: context) { $0.predicate = NSPredicate(format: "threadID == %@", "12345") }.count, 1)
    }
}
