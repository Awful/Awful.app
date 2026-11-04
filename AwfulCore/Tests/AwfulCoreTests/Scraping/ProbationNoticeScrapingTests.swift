//  ProbationNoticeScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader
import XCTest

final class ProbationNoticeScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testFixture() throws {
        let notice = try scrapeHTMLFixture(ProbationNoticeScrapeResult.self, named: "probation")
        XCTAssertEqual(notice.title, "YOU ARE A HORRIBLE MONSTER ON PROBATION!")
        XCTAssertEqual(notice.endDateText, "September 21, 2014 8:45 PM CST")
        XCTAssertTrue(notice.message.hasPrefix("You have been put on probation until September 21, 2014"))
        XCTAssertTrue(notice.message.hasSuffix("maybe this won't happen again!"))
    }

    func testCurrentMarkup() throws {
        let notice = try ProbationNoticeScrapeResult(HTMLDocument(string: currentPage), url: nil)
        XCTAssertEqual(notice.title, "TAKE A BREAK")
        XCTAssertEqual(notice.endDateText, "Nov 3, 2026 22:21")
        XCTAssertEqual(notice.message, "You have been put on probation until Nov 3, 2026 22:21. You cannot post while on probation. You might find out why you are on probation if you check the Leper's Colony. If you read the fucking rules, maybe this won't happen again!")
    }

    func testThreadListsWithoutNotice() throws {
        for fixture in ["forumdisplay", "bookmarkthreads"] {
            let result = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: fixture)
            XCTAssertNil(result.probationNotice, fixture)
        }
    }

    func testThreadListWithNotice() throws {
        let result = try ThreadListScrapeResult(HTMLDocument(string: currentPage), url: nil)
        XCTAssertEqual(result.probationNotice?.title, "TAKE A BREAK")
    }

    func testIgnoresNoticeInsidePost() {
        let html = """
            <body><div id="content"><div id="thread">
            <table class="post" id="post1"><tr><td class="postbody">
            <div id="probation_warn"><h4>GOTCHA</h4>You have been put on probation until never. You cannot post while on probation.</div>
            </td></tr></table>
            </div></div></body>
            """
        XCTAssertThrowsError(try ProbationNoticeScrapeResult(HTMLDocument(string: html), url: nil))
    }

    func testIgnoresNoticeNestedInPostAtTopLevel() {
        // Not a realistic page, but the ancestor check should still reject it.
        let html = """
            <body><div id="content"><table class="post"><tr><td class="postbody">
            <div id="probation_warn"><h4>GOTCHA</h4>Nope.</div>
            </td></tr></table></div></body>
            """
        XCTAssertThrowsError(try ProbationNoticeScrapeResult(HTMLDocument(string: html), url: nil))
    }
}

private let currentPage = """
    <body id="something_awful" class="usercp">
    <div style="display:none;" id="loggedinusername">Ihmemies</div>
    <div id="container">
    <div id="content">
    <div id="probation_warn">
    \t<h4>TAKE A BREAK</h4>
    \tYou have been put on probation until Nov 3, 2026 22:21. You cannot post while
    \ton probation.  You might find out why you are on probation if you
    \t<a href="/banlist.php?userid=190296">check the Leper's
    \tColony</a>.  If you <a href="//www.somethingawful.com/d/forum-rules/forum-rules.php">read the fucking rules</a>,
    \tmaybe this won't happen again!
    </div>
    </div>
    </div>
    </body>
    """
