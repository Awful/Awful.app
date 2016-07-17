//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

private let fixture = fixtureNamed(basename: "database-unavailable")

final class DatabaseUnavailableTests: ScrapingTestCase {
    func testForumHierarchy() {
        let scraper = AwfulForumHierarchyScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper?.error);
        XCTAssertTrue(fetchAll(type: Forum.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testPostsPage() {
        let scraper = AwfulPostsPageScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper?.error)
        XCTAssertTrue(fetchAll(type: Post.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testProfile() {
        let scraper = ProfileScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper?.error)
        XCTAssertTrue(fetchAll(type: User.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testThreadList() {
        let scraper = AwfulThreadListScraper.scrape(fixture, into:managedObjectContext)
        XCTAssertNotNil(scraper?.error)
        XCTAssertTrue(fetchAll(type: Thread.self, inContext: managedObjectContext).isEmpty)
    }
}
