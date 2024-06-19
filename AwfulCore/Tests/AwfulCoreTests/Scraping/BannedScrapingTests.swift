//  BannedScrapingTests.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class BannedScrapingTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testBanned() throws {
        let scraped = try scrapeHTMLFixture(BannedScrapeResult.self, named: "banned")
        
        let help = try XCTUnwrap(scraped.help)
        XCTAssertTrue(help.path.hasPrefix("/showthread.php"))

        let reason = try XCTUnwrap(scraped.reason)
        XCTAssertTrue(reason.path.hasPrefix("/banlist.php"))
    }

    func testNotBanned() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(BannedScrapeResult.self, named: "forumdisplay"))
    }
}
