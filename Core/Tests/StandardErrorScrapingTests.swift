//  StandardErrorScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class StandardErrorScrapingTests: XCTestCase {
    func testDatabaseUnavailable() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "database-unavailable"))
    }

    func testMustRegister() throws {
        let scraped = try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "error-must-register")
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("must be a registered forums member"))
    }

    func testNonError() throws {
        XCTAssertThrowsError(try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "banlist"))
        XCTAssertThrowsError(try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "showthread"))
    }

    func testRequiresArchives() throws {
        let scraped = try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "error-requires-archives")
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("archives upgrade"))
    }

    func testRequiresPlat() throws {
        let scraped = try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "error-requires-plat")
        XCTAssert(scraped.title.contains("Senor Lowtax"))
        XCTAssert(scraped.message.contains("only accessible to Platinum members"))
    }
    
    func testThreadClosed() throws {
        let scraped = try scrapeHTMLFixture(StandardErrorScrapeResult.self, named: "newreply-closed")
        XCTAssert(scraped.title.contains("Sorry!"))
        XCTAssert(scraped.message.contains("This thread is closed!"))
    }
}
