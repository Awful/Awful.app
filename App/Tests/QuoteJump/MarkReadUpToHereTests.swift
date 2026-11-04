//  MarkReadUpToHereTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// "Mark as read" in a post's action menu restyles the page in place: the chosen post and every post above it look seen, and every post below it looks unseen, without a reload.
///
/// Every theme draws seen state from the `seen` class on `<post>`, which is all `Awful.markReadUpToPostWithID` changes. A second seen marker anywhere in a post (as `divider-seen` on the footer divider once was) would keep its render-time state until the next reload, so the test also checks no such marker is in the document.
@MainActor
final class MarkReadUpToHereTests: XCTestCase {

    private var harness: PostsPageTestHarness!

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        try await super.tearDown()
    }

    func testMarkingReadMovesSeenStylingForwardAndBack() async throws {
        harness = try PostsPageTestHarness()
        try harness.setSeenPosts(109)
        // The thread is read through 109, so every post page 2 renders starts out seen and carries whatever seen markers the template writes.
        let page = try await harness.openPage(2)
        try await harness.waitForRender(of: page)

        // Back: posts after 60 go to unseen.
        try await markRead(upTo: 60, in: page)
        // Forward: posts up to 70 are seen again.
        try await markRead(upTo: 70, in: page)
    }

    private func markRead(upTo index: Int, in page: PostsPageViewController, file: StaticString = #filePath, line: UInt = #line) async throws {
        page.renderViewForTesting.markReadUpToPost(identifiedBy: QuoteJumpFixture.postID(forIndex: index))

        var states: [(index: Int, seen: Bool)] = []
        var strayMarkers = 0
        let deadline = Date().addingTimeInterval(5)
        repeat {
            (states, strayMarkers) = try await seenStates(in: page)
            if !states.isEmpty, states.allSatisfy({ $0.seen == ($0.index <= index) }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        } while Date() < deadline

        XCTAssertTrue(states.contains { $0.index == index }, "post \(index) should be in the document", file: file, line: line)
        for state in states {
            XCTAssertEqual(state.seen, state.index <= index, "after marking read up to \(index), post \(state.index) seen", file: file, line: line)
        }
        XCTAssertEqual(strayMarkers, 0, "seen state should live only in the seen class on <post>", file: file, line: line)
    }

    /// Each rendered post's thread index and whether it has the `seen` class, plus how many elements carry a `divider-seen` class.
    private func seenStates(in page: PostsPageViewController) async throws -> ([(index: Int, seen: Bool)], Int) {
        let js = """
        ({
          posts: Array.from(document.querySelectorAll('post')).map(p => [p.id, p.classList.contains('seen')]),
          stray: document.querySelectorAll('.divider-seen').length
        })
        """
        let result = try await harness.eval(js, in: page) as? [String: Any]
        let posts = (result?["posts"] as? [[Any]]) ?? []
        let states = posts.compactMap { pair -> (index: Int, seen: Bool)? in
            guard let id = pair.first as? String, let index = QuoteJumpFixture.index(ofPostID: id), let seen = pair.last as? Bool else { return nil }
            return (index, seen)
        }
        return (states, (result?["stray"] as? Int) ?? 0)
    }
}
