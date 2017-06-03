//  StandardErrorScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class StandardErrorScrapingTests: XCTestCase {
    func testDatabaseUnavailable() {
        XCTAssertThrowsError(try scrapeFixture(named: "database-unavailable") as StandardErrorScrapeResult)
    }

    func testMustRegister() {
        let scraped = try! scrapeFixture(named: "error-must-register") as StandardErrorScrapeResult
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("must be a registered forums member"))
    }

    func testNonError() {
        XCTAssertThrowsError(try scrapeFixture(named: "banlist") as StandardErrorScrapeResult)
        XCTAssertThrowsError(try scrapeFixture(named: "showthread") as StandardErrorScrapeResult)
    }

    func testRequiresArchives() {
        let scraped = try! scrapeFixture(named: "error-requires-archives") as StandardErrorScrapeResult
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("archives upgrade"))
    }

    func testRequiresPlat() {
        let scraped = try! scrapeFixture(named: "error-requires-plat") as StandardErrorScrapeResult
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("only accessible to Platinum members"))
    }
}
