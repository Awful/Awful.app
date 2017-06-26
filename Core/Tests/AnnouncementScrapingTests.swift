//  AnnouncementScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class AnnouncementScrapingTests: XCTestCase {
    override class func setUp() {
        super.setUp()

        makeUTCDefaultTimeZone()
    }

    func testRewrittenStore() {
        let result = try! scrapeFixture(named: "announcement") as AnnouncementListScrapeResult
        XCTAssertEqual(result.announcements.count, 1)

        let storeRewritten = result.announcements[0]
        XCTAssertEqual(storeRewritten.author?.username, "SA Support Robot")
        XCTAssert(storeRewritten.body.contains("Forums Store is once again open!"))
        XCTAssertEqual(storeRewritten.date?.timeIntervalSince1970, 1283644800)
    }
}
