//  PrivateMessageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class PrivateMessageScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return PrivateMessageScraper.self
    }
    
    func testSingleMessage() {
        let scraper = scrapeFixtureNamed("private-one") as PrivateMessageScraper
        let message = scraper.privateMessage
        XCTAssertTrue(fetchAll(PrivateMessage.self, inContext: managedObjectContext).count == 1)
        XCTAssertTrue(fetchAll(User.self, inContext: managedObjectContext).count == 1)
        
        XCTAssertEqual(message.messageID, "4601162")
        XCTAssertEqual(message.subject!, "Awful app")
        XCTAssertTrue(message.seen)
        XCTAssertFalse(message.replied)
        XCTAssertFalse(message.forwarded)
        XCTAssertEqual(message.sentDate!.timeIntervalSince1970, 1352408160)
        XCTAssertTrue(message.innerHTML!.rangeOfString("awesome app") != nil)
        let from = message.from!
        XCTAssertEqual(from.userID, "47395")
        XCTAssertEqual(from.username!, "InFlames235")
        XCTAssertEqual(from.regdate!.timeIntervalSince1970, 1073952000)
    }
}
