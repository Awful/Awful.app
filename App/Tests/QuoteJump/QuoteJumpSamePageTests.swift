//  QuoteJumpSamePageTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// Tapping a quote whose post is on the page already showing: the page scrolls to it rather than loading anything.
///
/// Every scenario opens page 2 of the `quotejump` fixture thread (see `Scripts/make-quotejump-fixtures.py`), where the reader has read through post 59, so posts 41–59 sit behind Previous Posts and the page opens at post 60, which holds the quotes being tapped.
///
/// | #   | Scenario                                                                              | Expected                                  |
/// |-----|---------------------------------------------------------------------------------------|-------------------------------------------|
/// | S1  | tap quote → 70 (below, nothing slow between)                                          | lands on 70, no route handed off          |
/// | S2  | tap quote → 76 (below, slow images in 72–74 between)                                  | still on 76 once the images have loaded   |
/// | S3  | tap quote → 42 (behind Previous Posts)                                                | posts revealed, lands on 42               |
/// | S3b | tap quote → 50 (behind Previous Posts, slow images in 45–47 above it once revealed)   | still on 50 once the images have loaded   |
/// | S4  | arrive via a post route to 60, tap quote → 70, tweets finish loading                  | still on 70                               |
/// | S5  | arrive via restoration anchored at 62, tap quote → 70, tweets finish loading          | still on 70                               |
/// | S6  | S4 with a drag before the tap                                                         | still on 70                               |
/// | S7  | click a post link inside a closed spoiler; reveal the spoiler; click again           | nothing, then lands on 70                 |
/// | S9  | endless scroll with page 3 appended, tap quote → 118 (slow images in 115 above it)    | lands on 118 without loading a page, and stays there once the images load |
/// | S10 | tap quote → 70, scroll away, tap it again                                             | lands on 70 both times                    |
/// | S11 | a real click on the quote link in the document (through WebKit's navigation delegate) | lands on 70                               |
///
/// S3b, S4, S5 and S9 document known defects and are marked `XCTExpectFailure`, so they pass while the defect stands and fail as soon as a fix lands (remove the marker then). S3 documents an intermittent one with a non-strict marker, so it never fails until the marker is made strict. Each failure message carries the observed landing: the target's offset, the post actually at the top, scroll position and how many images had loaded.
@MainActor
final class QuoteJumpSamePageTests: XCTestCase {

    private var harness: PostsPageTestHarness!

    override func setUp() async throws {
        try await super.setUp()
        // Stopping at the first failure makes XCTest suspend an async test until its time allowance runs out; keep going and let each test's later assertions add detail instead.
        continueAfterFailure = true
    }

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        try await super.tearDown()
    }

    private func makeHarness(endlessScroll: Bool = false) throws -> PostsPageTestHarness {
        let harness = try PostsPageTestHarness(endlessScroll: endlessScroll)
        try harness.setSeenPosts(59)
        self.harness = harness
        return harness
    }

    func testS1_quoteOfPostBelowScrollsToIt() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)
        XCTAssertEqual(page.hiddenPostsForTesting, 19, "posts 41–59 start out behind Previous Posts")
        let topVisible = try await harness.topVisiblePostIndex(in: page)
        XCTAssertEqual(topVisible, 60)

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)

        try await harness.assertLanded(on: 70, in: page)
        XCTAssert(harness.openedRoutes.isEmpty, "a same-page quote never hands off a route")
    }

    func testS2_quoteOfPostBelowSlowImagesStaysOnItOnceTheyLoad() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)

        harness.tapQuote(toIndex: 76, in: page)
        await harness.waitForScrollToSettle(in: page)
        // Images in 72–74 answer 2 s after the page asked for them; give them time to arrive and lay out.
        await harness.settle(milliseconds: 3000, in: page)

        XCTAssertGreaterThanOrEqual(harness.imageServer.servedCount, 3, "the three slow images above the target loaded")
        try await harness.assertLanded(on: 76, in: page, "S2: media between the tapped quote and its target shifted the landing")
    }

    func testS3_quoteOfHiddenPostRevealsAndScrollsToIt() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)
        let startsHidden = try await harness.isInDocument(index: 42, in: page)
        XCTAssertFalse(startsHidden, "post 42 starts out behind Previous Posts")

        harness.tapQuote(toIndex: 42, in: page)
        await harness.waitForScrollToSettle(in: page)

        XCTAssertEqual(page.hiddenPostsForTesting, 0)
        let revealed = try await harness.isInDocument(index: 42, in: page)
        XCTAssert(revealed)
        // Intermittent: `showHiddenSeenPosts` and the jump run as two separate tasks, each evaluating its own JavaScript, so the jump sometimes runs against a document the revealed posts haven't reached yet. Seen landing at the top of the page (the missing-element fallback sets `location.hash` to empty) and a post height short of the target. Non-strict so a run that happens to win the race doesn't fail; make it strict once the ordering is fixed.
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("Known intermittent defect: revealing hidden posts and jumping to one of them aren't ordered (S3)", options: options)
        try await harness.assertLanded(on: 42, in: page)
    }

    func testS3b_quoteOfHiddenPostBelowSlowImagesStaysOnItOnceTheyLoad() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)

        harness.tapQuote(toIndex: 50, in: page)
        await harness.waitForScrollToSettle(in: page)
        // Images in 45–47 answer 2 s after being revealed; give them time to arrive and lay out.
        await harness.settle(milliseconds: 3000, in: page)

        XCTAssertEqual(page.hiddenPostsForTesting, 0)
        XCTAssertGreaterThanOrEqual(harness.imageServer.servedCount, 3, "the three slow images above the target loaded")
        XCTExpectFailure("Known defect: images above the target finishing after the jump push it down and nothing re-scrolls (S3b)")
        try await harness.assertLanded(on: 50, in: page, "S3b: media above a revealed target shifted the landing")
    }

    func testS4_tweetsFinishingAfterASamePageTapDoNotPullBackToTheRouteTarget() async throws {
        let harness = try makeHarness()
        let page = try await harness.openViaPostRoute(toIndex: 60)
        try await harness.assertLanded(on: 60, in: page, "arriving via the route lands on 60")
        XCTAssertEqual(page.stagedJumpPostIDForTesting, QuoteJumpFixture.postID(forIndex: 60), "the route's target stays staged after landing")

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.assertLanded(on: 70, in: page, "the tap itself lands")

        try await harness.fireTweetsLoaded(in: page)

        XCTExpectFailure("Known defect: didTapLink's same-page branch leaves jumpToPostIDAfterLoading staged, so the tweet-loaded re-jump goes back to the route's target (S4)")
        try await harness.assertLanded(on: 70, in: page, "S4: a tweet finishing after a same-page quote tap yanked the reader back to the staged route target")
    }

    func testS5_tweetsFinishingAfterASamePageTapDoNotPullBackToTheRestorationAnchor() async throws {
        let harness = try makeHarness()
        let restoration = PendingPostsRestoration(scrollFraction: nil, hiddenPosts: 0, anchorPostID: QuoteJumpFixture.postID(forIndex: 62), anchorDelta: 0)
        let page = try await harness.openPage(2, restoring: restoration)
        try await harness.assertLanded(on: 62, in: page, "restoration lands on its anchor")

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.assertLanded(on: 70, in: page, "the tap itself lands")

        try await harness.fireTweetsLoaded(in: page)

        XCTExpectFailure("Known defect: didTapLink's same-page branch leaves anchorPostIDAfterLoading staged, so the tweet-loaded re-anchor goes back to the restoration anchor (S5)")
        try await harness.assertLanded(on: 70, in: page, "S5: a tweet finishing after a same-page quote tap re-anchored the reader to the restoration anchor")
    }

    func testS6_aDragBeforeTheTapProtectsTheTap() async throws {
        let harness = try makeHarness()
        let page = try await harness.openViaPostRoute(toIndex: 60)

        harness.drag(in: page)
        XCTAssertNil(page.stagedJumpPostIDForTesting)
        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.fireTweetsLoaded(in: page)

        try await harness.assertLanded(on: 70, in: page)
    }

    func testS7_linkInsideClosedSpoilerDoesNothingUntilOpened() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)
        let spoilerLink = "post[id=\"\(QuoteJumpFixture.postID(forIndex: 61))\"] .bbc-spoiler a"

        let clickedClosed = try await harness.click(spoilerLink, in: page)
        XCTAssert(clickedClosed)
        await harness.settle(milliseconds: 300, in: page)
        let topVisibleAfterClosedClick = try await harness.topVisiblePostIndex(in: page)
        XCTAssertEqual(topVisibleAfterClosedClick, 60, "a link in a closed spoiler is ignored")
        XCTAssert(harness.openedRoutes.isEmpty)

        // Reveal the spoiler by setting the class a tap on it toggles; a synthetic click on the span doesn't reach the body's click handler the way a real tap does.
        try await harness.eval("document.querySelector('post[id=\"\(QuoteJumpFixture.postID(forIndex: 61))\"] .bbc-spoiler').classList.add('spoiled')", in: page)
        await harness.settle(milliseconds: 100, in: page)
        let clickedOpen = try await harness.click(spoilerLink, in: page)
        XCTAssert(clickedOpen)
        await harness.waitForScrollToSettle(in: page)
        XCTAssert(harness.openedRoutes.isEmpty, "the link's post is on this page, so no route is handed off")

        try await harness.assertLanded(on: 70, in: page)
    }

    func testS9_quoteOfPostAppendedByEndlessScrollScrollsToIt() async throws {
        let harness = try makeHarness(endlessScroll: true)
        let page = try await harness.openPage(2)

        // Endless scroll appends page 3 in chunks as the reader nears the bottom; ask for it until it's all in.
        for _ in 0..<40 where page.posts.count < 80 {
            page.appendNextPageIfNeeded()
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(page.posts.count, 80, "page 3 appended")
        let appended = try await harness.isInDocument(index: 118, in: page)
        XCTAssert(appended)

        harness.tapQuote(toIndex: 118, in: page)
        await harness.waitForScrollToSettle(in: page)
        XCTAssert(harness.openedRoutes.isEmpty, "an appended post counts as on this page")
        try await harness.assertLanded(on: 118, in: page, "the tap itself lands")

        // Post 115's two images, appended with page 3, answer 1.5 s after being asked for.
        await harness.settle(milliseconds: 2500, in: page)
        XCTExpectFailure("Known defect: images above the target finishing after the jump push it down and nothing re-scrolls (S9)")
        try await harness.assertLanded(on: 118, in: page, "S9: media above the target in an appended page finishing after the jump shifted the landing")
    }

    func testS10_tappingTheSameQuoteTwiceLandsBothTimes() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.assertLanded(on: 70, in: page, "first tap")

        try await harness.eval("window.scrollTo(0, 0)", in: page)
        await harness.waitForScrollToSettle(in: page)
        let backAtTop = try await harness.topVisiblePostIndex(in: page)
        XCTAssertEqual(backAtTop, 60)

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.assertLanded(on: 70, in: page, "second tap")
    }

    func testS11_realClickOnQuoteLinkGoesThroughTheNavigationDelegate() async throws {
        let harness = try makeHarness()
        let page = try await harness.openPage(2)

        let selector = "post[id=\"\(QuoteJumpFixture.postID(forIndex: 60))\"] a.quote_link[href*=\"postid=\(QuoteJumpFixture.postID(forIndex: 70))\"]"
        let clicked = try await harness.click(selector, in: page)
        XCTAssert(clicked, "the quote link is in the rendered post")
        await harness.waitForScrollToSettle(in: page)

        try await harness.assertLanded(on: 70, in: page)
        XCTAssert(harness.openedRoutes.isEmpty)
    }
}
