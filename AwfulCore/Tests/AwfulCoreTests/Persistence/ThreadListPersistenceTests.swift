//  ThreadListPersistenceTests.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import XCTest

final class ThreadListPersistenceTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override class func setUp() {
        super.setUp()
        testInit()
    }

    override func setUp() {
        super.setUp()

        context = makeInMemoryStoreContext()
    }

    override func tearDown() {
        context = nil

        super.tearDown()
    }

    private func scrapeThreadList(named basename: String) throws {
        let fixture = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: basename)
        try _ = fixture.upsert(into: context)
    }

    private func fetchThreads() -> [AwfulThread] {
        AwfulThread.fetch(in: context) {
            $0.sortDescriptors = [
                .init(key: #keyPath(AwfulThread.sticky), ascending: false),
                .init(key: #keyPath(AwfulThread.lastModifiedDate), ascending: false),
            ]
        }
    }

    func testSomethingAwfulDiscussion() throws {
        try scrapeThreadList(named: "forumdisplay-sad")
        let threads = fetchThreads()
        XCTAssertEqual(threads.count, 18)
    }
}
