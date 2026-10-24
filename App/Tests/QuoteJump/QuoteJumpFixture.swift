//  QuoteJumpFixture.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/// The synthetic `quotejump` thread that `Scripts/make-quotejump-fixtures.py` generates: three pages of forty posts whose quotes point at posts chosen to exercise every quote-jump scenario. The generator's doc comment lists which post does what; this type knows the thread's ID, the post numbering and how to serve the pages through `FixtureURLProtocol`.
enum QuoteJumpFixture {

    static let threadID = "9000001"
    static let postsPerPage = 40
    static let pageCount = 3

    /// Which page-three file to serve: as the reader who has read through post 59 sees it (nothing on page three seen), as one who has read through post 109 sees it, or as one who has read through post 119 sees it (the last post unread, as after posting it).
    enum PageThreeVariant {
        case unread
        case seenThrough109
        case seenThrough119

        var fixtureName: String {
            switch self {
            case .unread: return "quotejump-p3"
            case .seenThrough109: return "quotejump-p3-seen109"
            case .seenThrough119: return "quotejump-p3-seen119"
            }
        }
    }

    private static let postIDBase = 900000000

    /// Post ID for the post at 1-based `index` in the thread: 900000000 + page * 100 + index on page, mirroring `post_id()` in the generator.
    static func postID(forIndex index: Int) -> String {
        let indexOnPage = (index - 1) % postsPerPage + 1
        return String(postIDBase + page(ofIndex: index) * 100 + indexOnPage)
    }

    /// The inverse of `postID(forIndex:)`, or nil for an ID that isn't one of the fixture's.
    static func index(ofPostID postID: String) -> Int? {
        guard let numeric = Int(postID), numeric > postIDBase else { return nil }
        let page = (numeric - postIDBase) / 100
        let indexOnPage = (numeric - postIDBase) % 100
        guard (1...pageCount).contains(page), (1...postsPerPage).contains(indexOnPage) else { return nil }
        return (page - 1) * postsPerPage + indexOnPage
    }

    static func page(ofIndex index: Int) -> Int {
        (index - 1) / postsPerPage + 1
    }

    /// The `goto=post` URL a quote link in a post carries, as `AwfulRoute` sees it once resolved against the Forums base URL.
    static func quoteLinkURL(toIndex index: Int) -> URL {
        quoteLinkURL(toPostID: postID(forIndex: index))
    }

    static func quoteLinkURL(toPostID id: String) -> URL {
        URL(string: "https://forums.somethingawful.com/showthread.php?goto=post&postid=\(id)#post\(id)")!
    }

    /// A fixture page's HTML with its image URLs pointed at `imageBase` (a `LocalImageServer.baseURL`).
    static func pageHTML(named name: String, imageBase: String) throws -> Data {
        let bundle = Bundle(for: BundleLocator.self)
        guard let url = bundle.url(forResource: name, withExtension: "html") else {
            throw FixtureError.missing(name)
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        return Data(html.replacingOccurrences(of: "{{IMAGE_BASE}}", with: imageBase).utf8)
    }

    /// The whole thread, ready for `FixtureURLProtocol.scriptedThreads`.
    static func scriptedThread(imageBase: String, pageThree: PageThreeVariant = .unread) throws -> FixtureURLProtocol.ScriptedThread {
        var postPages: [String: Int] = [:]
        for index in 1...(postsPerPage * pageCount) {
            postPages[postID(forIndex: index)] = page(ofIndex: index)
        }
        return FixtureURLProtocol.ScriptedThread(
            threadID: threadID,
            pages: [
                1: try pageHTML(named: "quotejump-p1", imageBase: imageBase),
                2: try pageHTML(named: "quotejump-p2", imageBase: imageBase),
                3: try pageHTML(named: pageThree.fixtureName, imageBase: imageBase),
            ],
            postPages: postPages,
            lastPage: pageCount,
            firstUnreadPage: pageThree == .unread ? 2 : 3
        )
    }

    enum FixtureError: Error {
        case missing(String)
    }

    private final class BundleLocator {}
}
