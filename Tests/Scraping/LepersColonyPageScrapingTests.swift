//  LepersColonyPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class LepersColonyPageScrapingTests: ScrapingTestCase {
    
    override class func scraperClass() -> AnyClass {
        return AwfulLepersColonyPageScraper.self
    }
    
    func testFirstPage() {
        let scraper = scrapeFixtureNamed("banlist") as AwfulLepersColonyPageScraper
        let bans = scraper.bans as [AwfulBan]
        XCTAssertTrue(bans.count == 50)
        XCTAssertTrue(User.numberOfObjectsInManagedObjectContext(managedObjectContext) == 71)
        XCTAssertTrue(Post.numberOfObjectsInManagedObjectContext(managedObjectContext) == 46)
        
        let first = bans[0]
        XCTAssertEqual(first.punishment, AwfulPunishment.Probation)
        XCTAssertEqual(first.post.postID, "421665753")
        XCTAssertEqual(first.date.timeIntervalSince1970, 1384078200)
        XCTAssertEqual(first.user.username!, "Kheldragar")
        XCTAssertEqual(first.user.userID!, "202925")
        XCTAssertTrue(first.reasonHTML.rangeOfString("shitty as you") != nil)
        XCTAssertEqual(first.requester.username!, "Ralp")
        XCTAssertEqual(first.requester.userID!, "61644")
        XCTAssertEqual(first.approver, first.requester)
    }
}
