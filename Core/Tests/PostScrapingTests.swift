//  PostScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PostScrapingTests: XCTestCase {
    func testIgnoredPost() throws {
        let result = try scrapeHTMLFixture(ShowPostScrapeResult.self, named: "showpost")
        XCTAssertEqual(result.author.username, "The Dave")
        XCTAssert(result.post.body.contains("Which command?"))
        XCTAssertEqual(result.threadID?.rawValue, "3510131")
        XCTAssertEqual(result.threadTitle, "Awful iPhone/iPad app - error code -1002")
    }
}
