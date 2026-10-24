//  QuoteJumpFixtureScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

/// Keeps `Scripts/make-quotejump-fixtures.py` honest: the synthetic `quotejump` thread pages must scrape exactly as the quote-jump test harness (App/Tests/QuoteJump) assumes, since every scenario there picks its targets by post index.
final class QuoteJumpFixtureScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    /// Mirror of `post_id()` in the generator: 900000000 + page * 100 + index on page.
    private func postID(forIndex index: Int) -> String {
        let page = (index - 1) / 40 + 1
        let indexOnPage = (index - 1) % 40 + 1
        return String(900000000 + page * 100 + indexOnPage)
    }

    private func scrapePage(_ fixtureName: String, expectingPage page: Int) throws -> PostsPageScrapeResult {
        let result = try scrapeHTMLFixture(PostsPageScrapeResult.self, named: fixtureName)
        XCTAssertEqual(result.threadID?.rawValue, "9000001", fixtureName)
        XCTAssertEqual(result.forumID?.rawValue, "1", fixtureName)
        XCTAssertEqual(result.threadTitle, "Quote Jump Fixture Thread", fixtureName)
        XCTAssertEqual(result.pageNumber, page, fixtureName)
        XCTAssertEqual(result.pageCount, 3, fixtureName)
        XCTAssertEqual(result.posts.count, 40, fixtureName)
        XCTAssertFalse(result.threadIsClosed, fixtureName)
        XCTAssertEqual(result.threadIsBookmarked, false, fixtureName)

        let firstIndex = (page - 1) * 40 + 1
        for (offset, post) in result.posts.enumerated() {
            let index = firstIndex + offset
            XCTAssertEqual(post.indexInThread, index, fixtureName)
            XCTAssertEqual(post.id.rawValue, postID(forIndex: index), fixtureName)
            XCTAssertNotNil(post.postDate, "\(fixtureName) post \(index) has an unparseable date")
            XCTAssertFalse(post.author.username.isEmpty, fixtureName)
        }
        return result
    }

    func testPageOneIsEntirelySeen() throws {
        let result = try scrapePage("quotejump-p1", expectingPage: 1)
        XCTAssert(result.posts.allSatisfy(\.hasBeenSeen))
        XCTAssertNil(result.jumpToPostIndex)
        XCTAssert(result.posts[0].authorIsOriginalPoster)

        XCTAssert(result.posts[4].body.contains("Target five"))
        XCTAssertEqual(result.posts[19].body.components(separatedBy: "<img ").count - 1, 3, "post 20 holds three images")
        XCTAssert(result.posts[29].body.contains("Target thirty"))
    }

    func testPageTwoIsSeenThroughFiftyNine() throws {
        let result = try scrapePage("quotejump-p2", expectingPage: 2)
        XCTAssertEqual(result.posts.prefix(19).filter(\.hasBeenSeen).count, 19, "posts 41-59 are seen")
        XCTAssertEqual(result.posts.dropFirst(19).filter(\.hasBeenSeen).count, 0, "posts 60-80 are unseen")
        XCTAssertEqual(result.jumpToPostIndex, 19, "post 60 is the first unseen post, at offset 19")

        XCTAssert(result.posts[1].body.contains("Target forty-two"))
        for offset in 4...6 {
            XCTAssert(result.posts[offset].body.contains("{{IMAGE_BASE}}/img/p2-\(41 + offset).png?delay=2000&amp;h=800"), "post \(41 + offset) holds one slow image")
        }
        XCTAssert(result.posts[9].body.contains("Target fifty"))
        XCTAssert(result.posts[14].body.contains("twitter.com/jack/status/20"))
        XCTAssert(result.posts[29].body.contains("Target seventy"))
        for offset in 31...33 {
            XCTAssert(result.posts[offset].body.contains("{{IMAGE_BASE}}/img/p2-\(41 + offset).png?delay=2000&amp;h=800"), "post \(41 + offset) holds one slow image")
        }
        XCTAssert(result.posts[35].body.contains("Target seventy-six"))

        let tapper = result.posts[19]
        let quotedIDs = [42, 50, 70, 76, 30, 5, 95, 118].map(postID(forIndex:)) + ["777777"]
        for quoted in quotedIDs {
            XCTAssert(tapper.body.contains("goto=post&amp;postid=\(quoted)#post\(quoted)"), "post 60 quotes \(quoted)")
        }
        XCTAssertEqual(tapper.body.components(separatedBy: "class=\"quote_link\"").count - 1, quotedIDs.count)

        let spoiler = result.posts[20]
        XCTAssert(spoiler.body.contains("bbc-spoiler"))
        XCTAssert(spoiler.body.contains("goto=post&amp;postid=\(postID(forIndex: 70))"))
    }

    func testPageThreeIsUnseen() throws {
        let result = try scrapePage("quotejump-p3", expectingPage: 3)
        XCTAssertEqual(result.posts.filter(\.hasBeenSeen).count, 0)
        XCTAssertNil(result.jumpToPostIndex, "no seen markers and no #pti fragment means no jump")
        XCTAssert(result.posts[14].body.contains("Target ninety-five"))
        XCTAssertEqual(result.posts[34].body.components(separatedBy: "<img ").count - 1, 2, "post 115 holds two images")
        XCTAssert(result.posts[37].body.contains("Target one eighteen"))
    }

    func testPageThreeSeenThroughOneHundredNine() throws {
        let result = try scrapePage("quotejump-p3-seen109", expectingPage: 3)
        XCTAssertEqual(result.posts.prefix(29).filter(\.hasBeenSeen).count, 29, "posts 81-109 are seen")
        XCTAssertEqual(result.posts.dropFirst(29).filter(\.hasBeenSeen).count, 0, "posts 110-120 are unseen")
        XCTAssertEqual(result.jumpToPostIndex, 29, "post 110 is the first unseen post, at offset 29")
        XCTAssertEqual(result.posts[29].id.rawValue, postID(forIndex: 110))
    }

    func testPageThreeSeenThroughOneHundredNineteen() throws {
        let result = try scrapePage("quotejump-p3-seen119", expectingPage: 3)
        XCTAssertEqual(result.posts.prefix(39).filter(\.hasBeenSeen).count, 39, "posts 81-119 are seen")
        XCTAssertFalse(result.posts[39].hasBeenSeen, "post 120 is unseen")
        XCTAssertEqual(result.jumpToPostIndex, 39, "post 120 is the first unseen post, at offset 39")
        XCTAssertEqual(result.posts[39].id.rawValue, postID(forIndex: 120))
    }

    func testPostIDsAreUniqueAcrossTheThread() throws {
        let pages = try ["quotejump-p1", "quotejump-p2", "quotejump-p3"].map { try scrapeHTMLFixture(PostsPageScrapeResult.self, named: $0) }
        let ids = pages.flatMap { $0.posts.map(\.id.rawValue) }
        XCTAssertEqual(Set(ids).count, 120)
        XCTAssertFalse(ids.contains("777777"), "the deleted post must not exist on any page")
    }
}
