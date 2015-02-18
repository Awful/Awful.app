//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

private let fixture = fixtureNamed("database-unavailable")

final class DatabaseUnavailableTests: ScrapingTestCase {
    func testForumHierarchy() {
        let scraper = AwfulForumHierarchyScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error);
        XCTAssertTrue(fetchAll(Forum.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testPostsPage() {
        let scraper = AwfulPostsPageScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(fetchAll(Post.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testProfile() {
        let scraper = ProfileScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(fetchAll(User.self, inContext: managedObjectContext).isEmpty)
    }
    
    func testThreadList() {
        let scraper = AwfulThreadListScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(fetchAll(Thread.self, inContext: managedObjectContext).isEmpty)
    }
}
