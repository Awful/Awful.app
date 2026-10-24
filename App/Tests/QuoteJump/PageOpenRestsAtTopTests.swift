//  PageOpenRestsAtTopTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// Opening a page lands at its top: the first post the reader should see sits right under the bars, not partly or wholly behind them.
///
/// The posts page sets its own top content inset for the bars, so a page resting at the top has a negative content offset. A scroll fraction taken there (or from a document that hasn't loaded, where it reads as zero) and applied to a shorter re-render used to put the top of the page under the bars.
///
/// Every scenario uses page 3 of the `quotejump` fixture thread as the reader who has read through post 109 sees it: posts 81–109 are read and hide behind Previous Posts, so a fresh render shows post 110 first.
///
/// | #   | Scenario                                                                           | Expected                  |
/// |-----|------------------------------------------------------------------------------------|---------------------------|
/// | O1  | page 3 cached, then opened: the cached render shows all 40 posts, the fetch hides 29 | post 110 at the top inset |
/// | O2  | page 3 rendered from the cache alone, then refreshed while resting at the top       | post 110 at the top inset |
/// | O3  | the thread opened at its next unread page, as a thread list does                    | post 110 at the top inset |
/// | O1a–O3a | the same under the app's own navigation controller with Reduce Liquid Glass and dark mode on, as reported | the same |
/// | O4  | restored from the cache at the top (anchored to post 110), rendered before the page is in a window  | post 110 at the top inset |
/// | O5  | rendered from the cache with nothing staged before the page is in a window                           | post 81 at the top inset  |
/// | O6  | page 2 opened at post 60, quote tapped to 70, the anchor the app would save then restored on a new page 2 | post 70 back at the top inset |
/// | O7  | read to the bottom of page 3, then a reply posted from the compose sheet: the page reloads at its next unread post (the reply) as the sheet goes away | post 120 at the top inset |
/// | O7a | the same under the app's own navigation controller with Reduce Liquid Glass and dark mode on, as reported | the same |
/// | O8  | rendered from the cache with nothing staged, left scrolled down by the toolbar's height as WebKit leaves the erased previous document | post 81 at the top inset |
/// | O9  | a page resting at the top that WebKit later moves to its scroll position zero, as it does on iOS 27 once posts below are measured | post 110 back at the top inset |
@MainActor
final class PageOpenRestsAtTopTests: XCTestCase {

    private var harness: PostsPageTestHarness!

    override func setUp() async throws {
        try await super.setUp()
        // Stopping at the first failure makes XCTest suspend an async test until its time allowance runs out; keep going and let each test's later assertions add detail instead.
        continueAfterFailure = true
    }

    private func makeHarness(appChrome: Bool = false) throws {
        harness = try PostsPageTestHarness(pageThree: .seenThrough109, appChrome: appChrome ? (reduceLiquidGlass: true, darkMode: true) : nil)
        try harness.setSeenPosts(109)
    }

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        try await super.tearDown()
    }

    func testO1_cachedPageReRenderedWithPostsHiddenRestsAtTop() async throws {
        try makeHarness()
        try await cachedPageReRenderedWithPostsHiddenRestsAtTop("O1")
    }

    func testO1a_cachedPageReRenderedWithPostsHiddenRestsAtTopUnderAppChrome() async throws {
        try makeHarness(appChrome: true)
        try await cachedPageReRenderedWithPostsHiddenRestsAtTop("O1a")
    }

    func testO2_refreshOfACachedRenderRestingAtTopStaysAtTop() async throws {
        try makeHarness()
        try await refreshOfACachedRenderRestingAtTopStaysAtTop("O2")
    }

    func testO2a_refreshOfACachedRenderRestingAtTopStaysAtTopUnderAppChrome() async throws {
        try makeHarness(appChrome: true)
        try await refreshOfACachedRenderRestingAtTopStaysAtTop("O2a")
    }

    func testO3_openingAtNextUnreadRestsAtTop() async throws {
        try makeHarness()
        try await openingAtNextUnreadRestsAtTop("O3")
    }

    func testO3a_openingAtNextUnreadRestsAtTopUnderAppChrome() async throws {
        try makeHarness(appChrome: true)
        try await openingAtNextUnreadRestsAtTop("O3a")
    }

    func testO4_restorationAtTheTopRenderedBeforeTheWindowRestsAtTop() async throws {
        try makeHarness()
        try await harness.cachePages([3])
        // What the app saves for a page resting at its top: the first post on screen, with the viewport top at its top edge.
        let restoration = PendingPostsRestoration(scrollFraction: nil, hiddenPosts: 29, anchorPostID: QuoteJumpFixture.postID(forIndex: 110), anchorDelta: 0)
        let page = try await harness.openPageRenderedBeforeInstall(3, restoring: restoration)
        XCTAssertEqual(page.hiddenPostsForTesting, 29)
        try await harness.assertRestingAtTop(in: page, firstPost: 110, "O4: the anchor was framed with the top inset the page had before it was in a window")
    }

    func testO5_nothingStagedRenderedBeforeTheWindowRestsAtTop() async throws {
        try makeHarness()
        try await harness.cachePages([3])
        let page = try await harness.openPageRenderedBeforeInstall(3, restoring: nil)
        try await harness.assertRestingAtTop(in: page, firstPost: 81, "O5: the document rested at the offset the page had before it was in a window")
    }

    /// The anchor the app saves while the reader is scrolled must restore to the same place. The saved delta is measured from the top of the bars' inset: at rest the first post reads at 0 in the document, while scrolled a post reads at its screen position, and only one of those is a bar height from the other.
    func testO6_savedAnchorRestoresTheScrolledPosition() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(59)
        let page = try await harness.openPage(2)
        try await harness.assertRestingAtTop(in: page, firstPost: 60, "page 2 opens at the first unread post")
        let anchorAtOpen = page.currentScrollAnchor?.postID

        harness.tapQuote(toIndex: 70, in: page)
        await harness.waitForScrollToSettle(in: page)
        try await harness.assertLanded(on: 70, in: page, "the tap lands")

        page.refreshRestorationAnchor()
        try await harness.waitUntil("the anchor to be refreshed after the jump") {
            page.currentScrollAnchor != nil && page.currentScrollAnchor?.postID != anchorAtOpen
        }
        guard let anchor = page.currentScrollAnchor else { return XCTFail("no anchor saved") }

        let restoration = PendingPostsRestoration(scrollFraction: nil, hiddenPosts: page.currentHiddenPosts, anchorPostID: anchor.postID, anchorDelta: anchor.deltaY)
        let restored = try await harness.openPage(2, restoring: restoration)
        try await harness.assertLanded(on: 70, in: restored, "O6: restoring the anchor saved with post 70 at the top (anchor \(anchor.postID), delta \(anchor.deltaY))")
    }

    func testO7_reloadAfterPostingAReplyRestsAtTop() async throws {
        try makeHarness()
        try await reloadAfterPostingAReplyRestsAtTop("O7")
    }

    func testO7a_reloadAfterPostingAReplyRestsAtTopUnderAppChrome() async throws {
        try makeHarness(appChrome: true)
        try await reloadAfterPostingAReplyRestsAtTop("O7a")
    }

    /// Erasing a page that was scrolled down clamps its offset to what fits the blank page, the toolbar's height. WebKit sometimes keeps that offset for the next document, so a page opened after posting a reply showed from partway down its first post.
    func testO8_freshDocumentLeftScrolledDownRestsAtTop() async throws {
        try makeHarness()
        try await harness.cachePages([3])
        let page = try await harness.openPageRenderedBeforeInstall(3, restoring: nil, leftoverOffset: 82)
        try await harness.assertRestingAtTop(in: page, firstPost: 81, "O8: the offset left over from the erased document was kept")
    }

    /// WebKit's scroll position zero is the top of the document, which ignores the inset the posts page sets for the bars. On iOS 27 WebKit sometimes moves a page there well after it has loaded.
    func testO9_restingPageResetToScrollPositionZeroReturnsToRest() async throws {
        try makeHarness()
        let page = try await harness.openNextUnread()
        try await harness.assertRestingAtTop(in: page, firstPost: 110, "the page opens at rest")

        let scrollView = page.renderViewForTesting.scrollView
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: 0)
        await harness.settle(milliseconds: 100, in: page)
        try await harness.assertRestingAtTop(in: page, firstPost: 110, "O9: the reset left the top of the page under the bars")
    }

    private func reloadAfterPostingAReplyRestsAtTop(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let page = try await harness.openPage(3)
        try await harness.waitUntil("the fetch to hide the read posts") { page.hiddenPostsForTesting == 29 }
        await harness.settle(milliseconds: 2000, in: page)
        await harness.scrollToBottom(in: page)
        await harness.presentComposeSheet(over: page)

        // What the reply workspace's completion does once the reply is posted: reload at the next unread post, now the reply, and dismiss the sheet.
        try harness.servePageThree(.seenThrough119)
        page.loadPage(.nextUnread, updatingCache: true, updatingLastReadPost: true)
        page.dismiss(animated: true, completion: nil)
        try await harness.waitForRender(of: page)
        try await harness.waitUntil("the reload to hide every post but the reply") { page.hiddenPostsForTesting == 39 && page.presentedViewController == nil }
        await harness.settle(milliseconds: 1000, in: page)

        try await harness.assertRestingAtTop(in: page, firstPost: 120, "\(scenario): the reload after posting", file: file, line: line)
    }

    private func cachedPageReRenderedWithPostsHiddenRestsAtTop(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await harness.cachePages([3])
        let page = try await harness.openPage(3)

        // The fetch's re-render can land before or after `openPage` returns; wait for its document.
        try await harness.waitUntil("the fetch to hide the read posts") {
            guard page.hiddenPostsForTesting == 29 else { return false }
            return try await !harness.isInDocument(index: 81, in: page)
        }
        await harness.settle(milliseconds: 500, in: page)

        try await harness.assertRestingAtTop(in: page, firstPost: 110, "\(scenario): the cached render's resting fraction was applied to the shorter re-render", file: file, line: line)
    }

    private func refreshOfACachedRenderRestingAtTopStaysAtTop(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await harness.cachePages([3])
        let page = try await harness.openPage(3, updatingCache: false)
        XCTAssertEqual(page.hiddenPostsForTesting, 0, "a cache-only render shows every post", file: file, line: line)
        try await harness.assertRestingAtTop(in: page, firstPost: 81, "\(scenario): a fresh render rests at the top", file: file, line: line)

        page.refreshContent()
        try await harness.waitForRender(of: page)
        await harness.settle(milliseconds: 500, in: page)

        XCTAssertEqual(page.hiddenPostsForTesting, 29, "the refresh hides the read posts", file: file, line: line)
        try await harness.assertRestingAtTop(in: page, firstPost: 110, "\(scenario): the 40-post document's resting fraction was applied to the 11-post document", file: file, line: line)
    }

    private func openingAtNextUnreadRestsAtTop(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let page = try await harness.openNextUnread()
        XCTAssertEqual(page.hiddenPostsForTesting, 29, "the next unread page opens at post 110", file: file, line: line)
        try await harness.assertRestingAtTop(in: page, firstPost: 110, "\(scenario): opening from a thread list", file: file, line: line)
    }
}
