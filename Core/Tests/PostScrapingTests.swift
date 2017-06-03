//  PostScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PostScrapingTests: XCTestCase {
    func testIgnoredPost() {
        let result = try! scrapeFixture(named: "showpost") as PostScrapeResult
        XCTAssert(result.body.contains("Which command?"))
        XCTAssertEqual(result.author.username, "The Dave")
    }
}
