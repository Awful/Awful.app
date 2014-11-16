//  PostScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class PostScrapingTests: ScrapingTestCase {
    
    override class func scraperClass() -> AnyClass {
        return AwfulPostScraper.self
    }
    
    func testIgnoredPost() {
        let scraper = scrapeFixtureNamed("showpost") as AwfulPostScraper
        let post = scraper.post
        XCTAssertTrue(post.innerHTML!.rangeOfString("Which command?") != nil)
        XCTAssertEqual(post.author!.username!, "The Dave")
    }
}
