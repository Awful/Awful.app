//  QuoteJumpCrossPageTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import AwfulCore
import XCTest

/// Tapping a quote whose post is on another page: the controller hands the `.post` route to the app, the router builds a new posts page for it (`PostLocator`), and that page scrolls to the post once rendered.
///
/// Every scenario starts on page 2 of the `quotejump` fixture thread (see `Scripts/make-quotejump-fixtures.py`), tapping quotes in post 60. Page 3 is served as the reader who has read through post 109 sees it, so post 95 is in its read region and 118 among its unread posts.
///
/// | #  | Scenario                                                                | Expected                                                        |
/// |----|-------------------------------------------------------------------------|-----------------------------------------------------------------|
/// | C1 | tap quote → 5 (page 1, already cached)                                  | `.post` route handed off; page 1 opens from the cache landed on 5 |
/// | C2 | tap quote → 95 (page 3, not cached, read region)                        | Forums asked where it is; page 3 lands on 95 with nothing hidden |
/// | C3 | tap quote → 118 (page 3, unread region)                                 | lands on 118                                                    |
/// | C4 | tap quote → 30 (page 1) with slow images in post 20 above it            | still on 30 once the images have loaded                         |
/// | C5 | C2, then tweets finish loading                                          | still on 95                                                     |
/// | C6 | tap quote → a deleted post                                              | locating it fails; no page opens                                 |
/// | C7 | the request that locates an uncached post                               | carries perpage=40 like every other posts request               |
///
/// C7 documents a known defect and is marked `XCTExpectFailure`, so it passes while the defect stands and fails as soon as a fix lands (remove the marker then).
@MainActor
final class QuoteJumpCrossPageTests: XCTestCase {

    private var harness: PostsPageTestHarness!

    override func setUp() async throws {
        try await super.setUp()
        // Stopping at the first failure makes XCTest suspend an async test until its time allowance runs out; keep going and let each test's later assertions add detail instead.
        continueAfterFailure = true
        harness = try PostsPageTestHarness(pageThree: .seenThrough109)
        try harness.setSeenPosts(109)
    }

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        try await super.tearDown()
    }

    /// Taps the quote of post `index` on page 2 and checks that the controller handed the app a `.post` route for it rather than scrolling.
    private func tapCrossPageQuote(toIndex index: Int, on page: PostsPageViewController) throws {
        harness.tapQuote(toIndex: index, in: page)
        XCTAssertEqual(harness.openedRoutes.count, 1, "a quote of a post on another page hands off exactly one route")
        guard case .post(id: let id, let updateSeen)? = harness.openedRoutes.last else {
            return XCTFail("expected a .post route, got \(String(describing: harness.openedRoutes.last))")
        }
        XCTAssertEqual(id, QuoteJumpFixture.postID(forIndex: index))
        guard case .noseen = updateSeen else { return XCTFail("quote links don't update the read marker") }
    }

    private var locateRequests: [URL] {
        FixtureURLProtocol.requestLog.filter { $0.query?.contains("goto=post") == true }
    }

    func testC1_quoteOfCachedPostOnEarlierPageOpensItFromTheCache() async throws {
        try await harness.cachePages([1])
        XCTAssertEqual(harness.cachedPost(index: 5)?.page, 1)
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 5, on: page)
        let target = try await harness.openViaPostRoute(toIndex: 5)

        XCTAssert(locateRequests.isEmpty, "a cached post's page is known; the Forums aren't asked")
        try await harness.assertLanded(on: 5, in: target)
    }

    func testC2_quoteOfUncachedPostInReadRegionOfLastPageLandsOnItWithNothingHidden() async throws {
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 95, on: page)
        let target = try await harness.openViaPostRoute(toIndex: 95)

        XCTAssertEqual(locateRequests.count, 1, "the Forums were asked where the post is")
        XCTAssertEqual(target.hiddenPostsForTesting, 0, "read posts stay visible when the target is among them")
        try await harness.assertLanded(on: 95, in: target)
    }

    func testC3_quoteOfUncachedPostAmongUnreadPostsLandsOnIt() async throws {
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 118, on: page)
        let target = try await harness.openViaPostRoute(toIndex: 118)

        try await harness.assertLanded(on: 118, in: target)
    }

    func testC4_slowImagesAboveTheTargetOnTheNewPageDoNotShiftIt() async throws {
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 30, on: page)
        let target = try await harness.openViaPostRoute(toIndex: 30)
        try await harness.assertLanded(on: 30, in: target, "the initial jump lands")
        // Post 20's three images answer after 1.5 s.
        await harness.settle(milliseconds: 2500, in: target)

        XCTAssertGreaterThanOrEqual(harness.imageServer.servedCount, 3, "the slow images above the target loaded")
        try await harness.assertLanded(on: 30, in: target, "C4: media above the target finishing after the jump shifted the landing")
    }

    func testC5_tweetsFinishingAfterTheJumpKeepTheTarget() async throws {
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 95, on: page)
        let target = try await harness.openViaPostRoute(toIndex: 95)
        try await harness.fireTweetsLoaded(in: target)

        try await harness.assertLanded(on: 95, in: target)
    }

    func testC6_quoteOfDeletedPostFailsToLocate() async throws {
        let page = try await harness.openPage(2)

        harness.tapQuote(toPostID: "777777", in: page)
        guard case .post(id: "777777", _)? = harness.openedRoutes.last else {
            return XCTFail("expected a .post route for the deleted post")
        }

        do {
            _ = try await harness.locateUncachedPost(id: "777777")
            XCTFail("locating a deleted post should fail")
        } catch {
            // The Forums answer a 200 with their standard "not found" page rather than a redirect, so `locatePost` reports that it found no page. (`PostLocator.withLocatingOverlay` shows "Post Not Found" for any error.)
            XCTAssert(error is AwfulCoreError, "unexpected error: \(error)")
        }
    }

    func testC7_locatingAPostAsksForFortyPostsPerPage() async throws {
        let page = try await harness.openPage(2)

        try tapCrossPageQuote(toIndex: 95, on: page)
        _ = try await harness.openViaPostRoute(toIndex: 95)

        let locate = try XCTUnwrap(locateRequests.first)
        XCTExpectFailure("Known defect: ForumsClient.locatePost doesn't send perpage=40, unlike every other posts request (C7)")
        XCTAssert(locate.query?.contains("perpage=40") == true, "C7: the goto=post request omits perpage=40, so the Forums answer with a page number for the account's own posts-per-page setting: \(locate)")
    }
}
