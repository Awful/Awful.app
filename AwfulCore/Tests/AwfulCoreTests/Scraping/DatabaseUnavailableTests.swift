//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class DatabaseUnavailableScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }
    
    func testDatabaseUnavailable() throws {
        let scraped = try scrapeHTMLFixture(DatabaseUnavailableScrapeResult.self, named: "database-unavailable")
        XCTAssert(scraped.title.contains("Database Unavailable"))
        XCTAssert(scraped.message.contains("currently not available"))
    }

    func testNonError() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(DatabaseUnavailableScrapeResult.self, named: "forumdisplay"))
        XCTAssertThrowsError(try scrapeHTMLFixture(DatabaseUnavailableScrapeResult.self, named: "profile"))
    }

    func testStandardError() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(DatabaseUnavailableScrapeResult.self, named: "error-must-register"))
    }
}
