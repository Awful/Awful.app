//  PostLinkRouteTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import AwfulCore
import XCTest

/// The post menu's "Copy link" makes a `goto=post` link. It used to share a thread page link with a `#post` fragment, and those links are still out there, so both must open the same post.
final class PostLinkRouteTests: XCTestCase {

    private let postID = "549471251"
    private let threadID = "3836680"

    /// Built the same way as the post menu's old "Share" link.
    private func legacyShareURL(page: ThreadPage?) -> URL {
        var components = URLComponents(string: "https://forums.somethingawful.com/showthread.php")!
        var queryItems = [
            URLQueryItem(name: "threadid", value: threadID),
            URLQueryItem(name: "perpage", value: "40"),
            URLQueryItem(name: "noseen", value: "1"),
        ]
        if case .specific(let pageNumber)? = page, pageNumber > 1 {
            queryItems.append(URLQueryItem(name: "pagenumber", value: "\(pageNumber)"))
        }
        components.queryItems = queryItems
        components.fragment = "post\(postID)"
        return components.url!
    }

    private var copyLinkURL: URL {
        AwfulRoute.post(id: postID, .noseen).httpURL
    }

    func testCopyLinkURLFormat() {
        XCTAssertEqual(copyLinkURL.absoluteString,
                       "https://forums.somethingawful.com/showthread.php?goto=post&postid=\(postID)&noseen=1")
    }

    func testCopyLinkOpensThePost() throws {
        XCTAssertEqual(try AwfulRoute(copyLinkURL).description, "post/\(postID)?update_seen=noseen")
    }

    func testLegacyShareLinkOpensTheSamePost() throws {
        let expected = try AwfulRoute(copyLinkURL).description
        for page: ThreadPage? in [nil, .first, .specific(1), .specific(14)] {
            let legacy = legacyShareURL(page: page)
            XCTAssertEqual(try AwfulRoute(legacy).description, expected, "\(legacy)")
        }
    }

    func testCopyLinkOpensThePostFromSafari() throws {
        let safari = try XCTUnwrap(URL(string: "awful" + copyLinkURL.absoluteString))
        XCTAssertEqual(try AwfulRoute(safari).description, try AwfulRoute(copyLinkURL).description)
    }
}
