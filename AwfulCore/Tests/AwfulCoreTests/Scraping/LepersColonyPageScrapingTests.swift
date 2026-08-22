//  LepersColonyPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class LepersColonyPageScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testFirstPage() throws {
        let result = try scrapeHTMLFixture(LepersColonyScrapeResult.self, named: "banlist")
        XCTAssertEqual(result.punishments.count, 50)
        
        let first = result.punishments[0]
        XCTAssertEqual(first.sentence, .probation)
        XCTAssertEqual(first.post?.rawValue, "421665753")
        XCTAssertEqual(first.date?.timeIntervalSince1970, 1384099800)
        XCTAssertEqual(first.subjectUsername, "Kheldragar")
        XCTAssertEqual(first.subject?.rawValue, "202925")
        XCTAssert(first.reason.contains("shitty as you"))
        XCTAssertEqual(first.requesterUsername, "Ralp")
        XCTAssertEqual(first.requester?.rawValue, "61644")
        XCTAssertEqual(first.approver, first.requester)
        XCTAssertEqual(first.approverUsername, first.requesterUsername)

        // This older fixture's `<div class="pages">` has no data-* attributes, so pagination is absent.
        XCTAssertNil(result.pageNumber)
        XCTAssertNil(result.pageCount)

        // The display-options form is present, so admin/year options parse.
        let options = try XCTUnwrap(result.filterOptions)
        XCTAssertEqual(options.admins.first, .init(id: .init(rawValue: "12831")!, username: "elpintogrande"))
        XCTAssert(options.years.contains(2013))
    }

    func testPagedFixture() throws {
        let result = try scrapeHTMLFixture(LepersColonyScrapeResult.self, named: "banlist-paged")

        // Pagination comes from `<div class="pages" data-current-page data-total-pages>`.
        XCTAssertEqual(result.pageNumber, 1)
        XCTAssertEqual(result.pageCount, 5866)

        XCTAssertEqual(result.punishments.count, 2)
        let first = result.punishments[0]
        XCTAssertEqual(first.sentence, .probation)
        XCTAssertEqual(first.post?.rawValue, "553203217")
        XCTAssertEqual(first.subjectUsername, "Ghost Leviathan")
        XCTAssertEqual(first.subject?.rawValue, "220511")
        XCTAssertEqual(result.punishments[1].sentence, .permaban)

        let options = try XCTUnwrap(result.filterOptions)
        XCTAssertEqual(options.admins, [
            .init(id: .init(rawValue: "18862")!, username: "Nyc_Tattoo"),
            .init(id: .init(rawValue: "40838")!, username: "VideoGames"),
        ])
        XCTAssertEqual(options.years, [2026, 2025])
    }
}
