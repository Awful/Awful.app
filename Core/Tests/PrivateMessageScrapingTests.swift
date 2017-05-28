//  PrivateMessageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PrivateMessageScrapingTests: XCTestCase {
    private var oldDefaultTimeZone: TimeZone?

    override func setUp() {
        super.setUp()

        oldDefaultTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(abbreviation: "UTC")!
    }

    override func tearDown() {
        if let oldDefaultTimeZone = oldDefaultTimeZone {
            NSTimeZone.default = oldDefaultTimeZone
        }

        super.tearDown()
    }

    func testSingleMessage() {
        let result = try! scrapeFixture(named: "private-one") as PrivateMessageScrapeResult

        XCTAssertEqual(result.privateMessageID, PrivateMessageID(rawValue: "4601162"))
        XCTAssertEqual(result.subject, "Awful app")
        XCTAssert(result.hasBeenSeen)
        XCTAssert(!result.wasRepliedTo)
        XCTAssert(!result.wasForwarded)
        XCTAssertEqual(result.sentDate?.timeIntervalSince1970, 1352408160)
        XCTAssert(result.body.rawValue.contains("awesome app"))
        XCTAssertEqual(result.author?.userID, UserID(rawValue: "47395"))
        XCTAssertEqual(result.author?.username, "InFlames235")
        XCTAssertEqual(result.author?.regdate?.timeIntervalSince1970, 1073952000)
    }
}
