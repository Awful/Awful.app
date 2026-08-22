//  GlossaryScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class GlossaryScrapingTests: XCTestCase {

    func testTopic() throws {
        let result = try scrapeHTMLFixture(GlossaryTopicScrapeResult.self, named: "glossary-topic")

        XCTAssertEqual(result.title, "Cougars")
        XCTAssertEqual(result.topicID, "1468")
        XCTAssertEqual(result.entries.count, 10)

        let first = result.entries.first!
        XCTAssertEqual(first.id, 0)
        XCTAssertEqual(first.authorUsername, "Kumo")
        XCTAssertEqual(first.authorUserID, "60171")
        XCTAssertEqual(first.postedDateText, "June 28, 2005")
        XCTAssertTrue(first.bodyHTML.contains("myspace"))

        // Usernames with symbols/spaces scrape intact.
        XCTAssertEqual(result.entries[4].authorUsername, "Hot Dog Day #48")
        XCTAssertTrue(result.entries[4].bodyHTML.contains("<br"), "line breaks preserved in body HTML")

        // A body containing a link keeps the anchor markup.
        let arsePornCage = result.entries[8]
        XCTAssertEqual(arsePornCage.authorUsername, "Arse Porn Cage")
        XCTAssertTrue(arsePornCage.bodyHTML.contains("showthread.php"))

        let last = result.entries.last!
        XCTAssertEqual(last.authorUsername, "funny way to spell")
        XCTAssertEqual(last.authorUserID, "192712")
        XCTAssertEqual(last.postedDateText, "September 21, 2015")
    }

    func testLetterIndex() throws {
        let result = try scrapeHTMLFixture(GlossaryIndexScrapeResult.self, named: "glossary-index")

        XCTAssertEqual(result.totalEntryCount, 2287)
        XCTAssertGreaterThanOrEqual(result.topics.count, 100)

        let first = result.topics.first!
        XCTAssertEqual(first.title, "d(-_-)b")
        XCTAssertEqual(first.topicID, "2657")
        XCTAssertEqual(first.id, "2657")

        let last = result.topics.last!
        XCTAssertEqual(last.title, "DYP")
        XCTAssertEqual(last.topicID, "2958")

        // HTML entities in titles are decoded.
        XCTAssertTrue(result.topics.contains { $0.title == "Dating & Relationships" && $0.topicID == "2095" })
        XCTAssertTrue(result.topics.contains { $0.title == "Demonius Darkblade's Retrogaming Dungeon" })
    }
}
