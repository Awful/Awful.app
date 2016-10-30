//  PrivateMessageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class PrivateMessageScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return PrivateMessageScraper.self
    }
    
    override func setUp() {
        super.setUp()
        
        NSTimeZone.default = TimeZone(abbreviation: "UTC")!
    }

    func testSingleMessage() {
        let scraper = scrapeFixtureNamed("private-one") as! PrivateMessageScraper
        let message = scraper.privateMessage
        XCTAssert(fetchAll(PrivateMessage.self, inContext: managedObjectContext).count == 1)
        XCTAssert(fetchAll(User.self, inContext: managedObjectContext).count == 1)
        
        XCTAssert(message?.messageID == "4601162")
        XCTAssert(message?.subject == "Awful app")
        XCTAssert((message?.seen)!)
        XCTAssert(!(message?.replied)!)
        XCTAssert(!(message?.forwarded)!)
        XCTAssertEqual(message?.sentDate!.timeIntervalSince1970, 1352408160)
        XCTAssert(message?.innerHTML!.range(of: "awesome app") != nil)
        let from = message?.from!
        XCTAssert(from?.userID == "47395")
        XCTAssert(from?.username == "InFlames235")
        XCTAssertEqual(from?.regdate!.timeIntervalSince1970, 1073952000)
    }
}
