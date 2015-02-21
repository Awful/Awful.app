//  LepersColonyPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class LepersColonyPageScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return LepersColonyPageScraper.self
    }
    
    func testFirstPage() {
        let scraper = scrapeFixtureNamed("banlist") as LepersColonyPageScraper
        let punishments = scraper.punishments as [Punishment]
        XCTAssert(punishments.count == 50)
        XCTAssert(fetchAll(User.self, inContext: managedObjectContext).count == 71)
        XCTAssert(fetchAll(Post.self, inContext: managedObjectContext).count == 46)
        
        let first = punishments[0]
        XCTAssert(first.sentence == PunishmentSentence.Probation)
        XCTAssert(first.post!.postID == "421665753")
        XCTAssert(first.date.timeIntervalSince1970 == 1384078200)
        XCTAssert(first.subject.username == "Kheldragar")
        XCTAssert(first.subject.userID == "202925")
        XCTAssert(first.reasonHTML!.rangeOfString("shitty as you") != nil)
        XCTAssert(first.requester!.username == "Ralp")
        XCTAssert(first.requester!.userID == "61644")
        XCTAssert(first.approver! == first.requester!)
    }
}
