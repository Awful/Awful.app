//  LepersColonyPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class LepersColonyPageScrapingTests: XCTestCase {
    override class func setUp() {
        super.setUp()

        makeUTCDefaultTimeZone()
    }

    func testFirstPage() {
        let result = try! scrapeFixture(named: "banlist") as LepersColonyScrapeResult
        XCTAssertEqual(result.punishments.count, 50)
        
        let first = result.punishments[0]
        XCTAssertEqual(first.sentence, .probation)
        XCTAssertEqual(first.post?.rawValue, "421665753")
        XCTAssertEqual(first.date?.timeIntervalSince1970, 1384078200)
        XCTAssertEqual(first.subjectUsername, "Kheldragar")
        XCTAssertEqual(first.subject?.rawValue, "202925")
        XCTAssert(first.reason.contains("shitty as you"))
        XCTAssertEqual(first.requesterUsername, "Ralp")
        XCTAssertEqual(first.requester?.rawValue, "61644")
        XCTAssertEqual(first.approver, first.requester)
        XCTAssertEqual(first.approverUsername, first.requesterUsername)
    }
}
