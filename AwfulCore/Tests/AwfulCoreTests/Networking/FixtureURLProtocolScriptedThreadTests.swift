//  FixtureURLProtocolScriptedThreadTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader
import XCTest

/// `FixtureURLProtocol`'s scripted-thread mode is what the quote-jump harness (App/Tests/QuoteJump) feeds `ForumsClient` with, so its answers need to look enough like the Forums' for `listPosts` and `locatePost` to be none the wiser.
final class FixtureURLProtocolScriptedThreadTests: XCTestCase {

    private var session: URLSession!

    override func setUp() {
        super.setUp()
        FixtureURLProtocol.resetScripting()
        FixtureURLProtocol.scriptedThreads["123"] = .init(
            threadID: "123",
            pages: [
                1: Data("<html><body data-thread='123'>page one</body></html>".utf8),
                2: Data("<html><body data-thread='123'>page two</body></html>".utf8),
            ],
            postPages: ["1001": 1, "2001": 2],
            lastPage: 2,
            firstUnreadPage: 2
        )
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self] + (config.protocolClasses ?? [])
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        FixtureURLProtocol.resetScripting()
        session = nil
        super.tearDown()
    }

    private func forumsURL(_ pathAndQuery: String) -> URL {
        URL(string: "https://forums.somethingawful.com\(pathAndQuery)")!
    }

    func testServesTheRequestedPage() async throws {
        let (data, response) = try await session.data(from: forumsURL("/showthread.php?threadid=123&perpage=40&pagenumber=2&noseen=1"))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Type"), "text/html; charset=utf-8")
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "<html><body data-thread='123'>page two</body></html>")
        XCTAssertEqual(FixtureURLProtocol.requestLog.map(\.absoluteString), ["https://forums.somethingawful.com/showthread.php?threadid=123&perpage=40&pagenumber=2&noseen=1"])
    }

    func testMissingPageIsNotFound() async throws {
        let (_, response) = try await session.data(from: forumsURL("/showthread.php?threadid=123&pagenumber=9"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
    }

    func testGotoPostRedirectsToThePostsPage() async throws {
        var redirect: (response: HTTPURLResponse, request: URLRequest)?
        let (_, response) = try await session.data(for: URLRequest(url: forumsURL("/showthread.php?goto=post&postid=2001&noseen=1"))) { response, newRequest in
            redirect = (response, newRequest)
            return newRequest
        }

        let seen = try XCTUnwrap(redirect)
        XCTAssertEqual(seen.response.statusCode, 302)
        let location = try XCTUnwrap(seen.request.url)
        XCTAssertEqual(location.absoluteString, "https://forums.somethingawful.com/showthread.php?threadid=123&pagenumber=2#post2001", "like the Forums', the redirect carries no perpage")

        // Following the redirect lands on the page itself.
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(response.url?.absoluteString, location.absoluteString)
        XCTAssertEqual(FixtureURLProtocol.requestLog.count, 2)
    }

    func testRefusingTheRedirectStillReportsIt() async throws {
        // `ForumsClient.locatePost` reads the page from the redirect and then declines to follow it.
        var locationSeen: URL?
        let (_, response) = try await session.data(for: URLRequest(url: forumsURL("/showthread.php?goto=post&postid=1001"))) { _, newRequest in
            locationSeen = newRequest.url
            return nil
        }
        XCTAssertEqual(locationSeen?.absoluteString, "https://forums.somethingawful.com/showthread.php?threadid=123&pagenumber=1#post1001")
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 302)
    }

    func testUnknownPostIsAForumsStandardError() async throws {
        let (data, response) = try await session.data(from: forumsURL("/showthread.php?goto=post&postid=777777"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let document = HTMLDocument(data: data, contentTypeHeader: "text/html; charset=utf-8")
        let error = try StandardErrorScrapeResult(document, url: nil)
        XCTAssertEqual(error.title, "Specified post was not found")
        XCTAssert(error.message.contains("does not exist"))
    }

    func testNewPostAndLastPostRedirect() async throws {
        var locations: [String] = []
        _ = try await session.data(for: URLRequest(url: forumsURL("/showthread.php?threadid=123&goto=newpost"))) { _, newRequest in
            locations.append(newRequest.url!.absoluteString)
            return nil
        }
        _ = try await session.data(for: URLRequest(url: forumsURL("/showthread.php?threadid=123&goto=lastpost"))) { _, newRequest in
            locations.append(newRequest.url!.absoluteString)
            return nil
        }
        XCTAssertEqual(locations, [
            "https://forums.somethingawful.com/showthread.php?threadid=123&pagenumber=2",
            "https://forums.somethingawful.com/showthread.php?threadid=123&pagenumber=2",
        ])
    }

    func testOtherForumsPagesAreEmptyWhileScripting() async throws {
        let (data, response) = try await session.data(from: forumsURL("/forumdisplay.php?forumid=1"))
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssert(data.isEmpty)
    }

    func testDoesNothingWithoutScriptedThreads() {
        FixtureURLProtocol.resetScripting()
        XCTAssertFalse(FixtureURLProtocol.canInit(with: URLRequest(url: forumsURL("/showthread.php?threadid=123&pagenumber=1"))))
        XCTAssertFalse(FixtureURLProtocol.canInit(with: URLRequest(url: forumsURL("/forumdisplay.php?forumid=1"))))
    }

    func testIgnoresOtherHosts() {
        XCTAssertFalse(FixtureURLProtocol.canInit(with: URLRequest(url: URL(string: "https://example.com/showthread.php?threadid=123")!)))
    }
}
