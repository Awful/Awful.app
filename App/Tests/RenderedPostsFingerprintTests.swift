//  RenderedPostsFingerprintTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

/// A restored page refreshes in the background and only re-renders when the fingerprint of what
/// it would show differs from what's on screen. A false "changed" costs a visible re-render on
/// launch; a false "unchanged" leaves stale posts up.
final class RenderedPostsFingerprintTests: XCTestCase {

    private typealias Entry = RenderedPostsFingerprint.Entry

    private let onScreen = RenderedPostsFingerprint(entries: [
        Entry(postID: "1", innerHTML: "<p>first</p>", ignored: false),
        Entry(postID: "2", innerHTML: "<p>second</p>", ignored: false),
    ])

    func testSameContentIsUnchanged() {
        let fetched = RenderedPostsFingerprint(entries: [
            Entry(postID: "1", innerHTML: "<p>first</p>", ignored: false),
            Entry(postID: "2", innerHTML: "<p>second</p>", ignored: false),
        ])
        XCTAssertEqual(fetched, onScreen)
    }

    func testEditedPostIsChanged() {
        let fetched = RenderedPostsFingerprint(entries: [
            Entry(postID: "1", innerHTML: "<p>first</p>", ignored: false),
            Entry(postID: "2", innerHTML: "<p>second (edited)</p>", ignored: false),
        ])
        XCTAssertNotEqual(fetched, onScreen)
    }

    func testAppendedReplyIsChanged() {
        let fetched = RenderedPostsFingerprint(entries: onScreen.entries + [
            Entry(postID: "3", innerHTML: "<p>new reply</p>", ignored: false),
        ])
        XCTAssertNotEqual(fetched, onScreen)
    }

    func testNewlyIgnoredAuthorIsChanged() {
        let fetched = RenderedPostsFingerprint(entries: [
            Entry(postID: "1", innerHTML: "<p>first</p>", ignored: true),
            Entry(postID: "2", innerHTML: "<p>second</p>", ignored: false),
        ])
        XCTAssertNotEqual(fetched, onScreen)
    }

    func testDifferentHiddenPostsOffsetIsChanged() {
        // Fingerprints cover only the posts after `hiddenPosts`, so the same page with a
        // different number of hidden posts renders a different document.
        let fetched = RenderedPostsFingerprint(entries: Array(onScreen.entries.dropFirst()))
        XCTAssertNotEqual(fetched, onScreen)
    }
}
