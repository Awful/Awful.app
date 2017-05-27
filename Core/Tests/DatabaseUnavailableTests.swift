//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

private let fixture = fixtureNamed("database-unavailable")

final class DatabaseUnavailableScrapingTests: XCTestCase {
    func testDatabaseUnavailable() {
        let scraped = try! scrapeFixture(named: "database-unavailable") as DatabaseUnavailableScrapeResult
        XCTAssert(scraped.title.contains("Database Unavailable"))
        XCTAssert(scraped.message.contains("currently not available"))
    }

    func testNonError() {
        XCTAssertThrowsError(try scrapeFixture(named: "forumdisplay") as DatabaseUnavailableScrapeResult)
        XCTAssertThrowsError(try scrapeFixture(named: "profile") as DatabaseUnavailableScrapeResult)
    }

    func testStandardError() {
        XCTAssertThrowsError(try scrapeFixture(named: "error-must-register") as DatabaseUnavailableScrapeResult)
    }
}
