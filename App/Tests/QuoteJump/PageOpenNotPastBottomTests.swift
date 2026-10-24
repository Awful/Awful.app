//  PageOpenNotPastBottomTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// Opening a page near its end never leaves it scrolled past the end, with the bottom of the last post partway up the screen above blank space.
///
/// Posts that haven't been drawn yet count at a 600pt placeholder height (`content-visibility: auto` in the posts stylesheet), and the fixture's last posts on page 3 are a couple of lines each, so a jump near the end is worked out against a document far taller than it ends up. These scenarios check the page still ends no further down than its end once those posts draw.
///
/// | #   | Scenario                                                                                       | Expected                                  |
/// |-----|------------------------------------------------------------------------------------------------|-------------------------------------------|
/// | B1  | the thread opened at its last post (the Last Post button)                                      | post 120 on screen, page at its end       |
/// | B2  | page 3 restored at a scroll fraction near its end                                              | page no further than its end              |
/// | B2a | page 3 restored anchored to its last post                                                      | post 120 on screen, page at its end       |
/// | B3  | the route to post 118, two short posts from the end                                            | post 118 on screen, page at its end       |
///
/// Each scenario checks again once the slow images in post 115 have loaded and once more after the "tweets loaded" re-jump.
@MainActor
final class PageOpenNotPastBottomTests: XCTestCase {

    private var harness: PostsPageTestHarness!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = true
    }

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        try await super.tearDown()
    }

    func testB1_openingAtTheLastPostStopsAtTheEnd() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(59)
        let page = try await harness.openLastPost()
        try await assertLandedThroughout(on: 120, in: page, "B1")
    }

    func testB2_restoredFractionNearTheEndStopsAtTheEnd() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(59)
        try await harness.cachePages([3])
        let restoration = PendingPostsRestoration(scrollFraction: 0.98, hiddenPosts: 0, anchorPostID: nil, anchorDelta: nil)
        let page = try await harness.openPage(3, updatingCache: false, restoring: restoration)
        harness.assertNotOverscrolled(in: page, "B2: once rendered")
        await harness.settle(milliseconds: 2000, in: page)
        harness.assertNotOverscrolled(in: page, "B2: once the images in post 115 have loaded")
        try await harness.fireTweetsLoaded(in: page)
        harness.assertNotOverscrolled(in: page, "B2: after tweets loaded")
    }

    func testB2a_restoredAnchorOnTheLastPostStopsAtTheEnd() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(59)
        try await harness.cachePages([3])
        let restoration = PendingPostsRestoration(scrollFraction: nil, hiddenPosts: 0, anchorPostID: QuoteJumpFixture.postID(forIndex: 120), anchorDelta: 0)
        let page = try await harness.openPage(3, updatingCache: false, restoring: restoration)
        try await assertLandedThroughout(on: 120, in: page, "B2a")
    }

    func testB3_routeToAPostNearTheEndStopsAtTheEnd() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(59)
        try await harness.cachePages([3])
        let page = try await harness.openViaPostRoute(toIndex: 118)
        try await assertLandedThroughout(on: 118, in: page, "B3")
    }

    private func assertLandedThroughout(on index: Int, in page: PostsPageViewController, _ scenario: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        try await harness.assertLanded(on: index, in: page, "\(scenario): once rendered", file: file, line: line)
        await harness.settle(milliseconds: 2000, in: page)
        try await harness.assertLanded(on: index, in: page, "\(scenario): once the images in post 115 have loaded", file: file, line: line)
        try await harness.fireTweetsLoaded(in: page)
        try await harness.assertLanded(on: index, in: page, "\(scenario): after tweets loaded", file: file, line: line)
    }
}
