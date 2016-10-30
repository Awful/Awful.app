//  MessageFolderScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import XCTest

final class MessageFolderScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return PrivateMessageFolderScraper.self
    }
    
    override func setUp() {
        super.setUp()
        
        NSTimeZone.default = TimeZone(abbreviation: "UTC")!
    }

    func testInbox() {
        let scraper = scrapeFixtureNamed("private-list") as! PrivateMessageFolderScraper
        let messages = scraper.messages
        XCTAssert(messages?.count == 4)
        XCTAssert(messages!.count == fetchAll(PrivateMessage.self, inContext: managedObjectContext).count)
        
        let tagged = fetchOne(PrivateMessage.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "rawFromUsername = 'CamH'"))!
        XCTAssert(tagged.messageID == "4549686")
        XCTAssert(tagged.subject == "Re: Awful app etc.")
        XCTAssertEqual(tagged.sentDate!.timeIntervalSince1970, 1348778940)
        XCTAssert(tagged.threadTag!.imageName == "sex")
        XCTAssert(tagged.replied)
        XCTAssert(tagged.seen)
        XCTAssert(!tagged.forwarded)
    }
}
