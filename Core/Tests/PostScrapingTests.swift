//  PostScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class PostScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return AwfulPostScraper.self
    }
    
    func testIgnoredPost() {
        let scraper = scrapeFixtureNamed("showpost") as! AwfulPostScraper
        let post = scraper.post
        XCTAssert(post.innerHTML!.rangeOfString("Which command?") != nil)
        XCTAssert(post.author!.username == "The Dave")
    }
}
