//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

private let fixture = fixtureNamed("database-unavailable")

final class DatabaseUnavailableTests: ScrapingTestCase {
    func testForumHierarchy() {
        let scraper = AwfulForumHierarchyScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper.error);
        XCTAssertTrue(fetchAll(Forum.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testPostsPage() {
        let scraper = AwfulPostsPageScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(fetchAll(Post.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testThreadList() {
        let scraper = AwfulThreadListScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(fetchAll(AwfulThread.self, inContext: managedObjectContext).isEmpty)
    }
}
