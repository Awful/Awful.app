//  AnnouncementScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class AnnouncementScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testRewrittenStore() throws {
        let result = try scrapeHTMLFixture(AnnouncementListScrapeResult.self, named: "announcement")
        XCTAssertEqual(result.announcements.count, 1)

        let storeRewritten = result.announcements[0]
        XCTAssertEqual(storeRewritten.author?.username, "SA Support Robot")
        XCTAssert(storeRewritten.body.contains("Forums Store is once again open!"))
        XCTAssertEqual(storeRewritten.date?.timeIntervalSince1970, 1283662800)
    }

    func testTwoAnnouncements() throws {
        let result = try scrapeHTMLFixture(AnnouncementListScrapeResult.self, named: "announcement-two")
        XCTAssertEqual(result.announcements.count, 2)

        let patreon = result.announcements[0]
        XCTAssertEqual(patreon.author?.username, "Lowtax")
        XCTAssert(patreon.body.contains("I've set up a Patreon"))
        XCTAssert(patreon.body.contains("thank you for loving Pupkin"))

        let xenforo = result.announcements[1]
        XCTAssertEqual(xenforo.author?.username, "Lowtax")
        XCTAssert(xenforo.body.contains("No ETA, no nothing."))
        XCTAssert(xenforo.body.contains("Revenue is around"))
    }
}
