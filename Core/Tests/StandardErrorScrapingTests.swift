//
//  StandardErrorScrapingTests.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-27.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

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
}
