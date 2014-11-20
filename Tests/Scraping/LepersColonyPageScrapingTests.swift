//  LepersColonyPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class LepersColonyPageScrapingTests: ScrapingTestCase {
    
    override class func scraperClass() -> AnyClass {
        return LepersColonyPageScraper.self
    }
    
    func testFirstPage() {
        let scraper = scrapeFixtureNamed("banlist") as LepersColonyPageScraper
        let punishments = scraper.punishments as [Punishment]
        XCTAssertTrue(punishments.count == 50)
        XCTAssertTrue(User.numberOfObjectsInManagedObjectContext(managedObjectContext) == 71)
        XCTAssertTrue(Post.numberOfObjectsInManagedObjectContext(managedObjectContext) == 46)
        
        let first = punishments[0]
        XCTAssertEqual(first.sentence, PunishmentSentence.Probation)
        XCTAssertEqual(first.post!.postID, "421665753")
        XCTAssertEqual(first.date.timeIntervalSince1970, 1384078200)
        XCTAssertEqual(first.subject.username!, "Kheldragar")
        XCTAssertEqual(first.subject.userID!, "202925")
        XCTAssertTrue(first.reasonHTML!.rangeOfString("shitty as you") != nil)
        XCTAssertEqual(first.requester!.username!, "Ralp")
        XCTAssertEqual(first.requester!.userID!, "61644")
        XCTAssertEqual(first.approver!, first.requester!)
    }
}
