//  DatabaseUnavailableTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

private let fixture = loadFixtureNamed("database-unavailable")

class DatabaseUnavailableTests: ScrapingTestCase {
    
    func testForumHierarchy() {
        let scraper = AwfulForumHierarchyScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error);
        XCTAssertTrue(Forum.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
    }
    
    func testPostsPage() {
        let scraper = AwfulPostsPageScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(Post.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
    }
    
    func testProfile() {
        let scraper = ProfileScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(User.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
    }
    
    func testThreadList() {
        let scraper = AwfulThreadListScraper.scrapeNode(fixture, intoManagedObjectContext:managedObjectContext)
        XCTAssertNotNil(scraper.error)
        XCTAssertTrue(Thread.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
    }
}
