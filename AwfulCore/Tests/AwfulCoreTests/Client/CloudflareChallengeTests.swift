//  CloudflareChallengeTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class CloudflareChallengeTests: XCTestCase {

    private let url = URL(string: "https://forums.somethingawful.com/showthread.php?threadid=1")!

    private func fixtureData(named basename: String) throws -> Data {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: basename, withExtension: "html", subdirectory: "Fixtures"))
        return try Data(contentsOf: fixtureURL)
    }

    private func detect(
        method: String = "GET",
        status: Int,
        headers: [String: String] = [:],
        body: Data
    ) -> CloudflareChallenge? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return CloudflareChallenge(request: request, response: response, data: body)
    }

    func testHeaderAndBody() throws {
        let challenge = try XCTUnwrap(detect(
            status: 403,
            headers: ["cf-mitigated": "challenge", "Server": "cloudflare", "cf-ray": "8f1e2d3c4b5a6978-LHR"],
            body: fixtureData(named: "cloudflare-challenge")
        ))
        XCTAssertEqual(challenge.url, url)
        XCTAssertEqual(challenge.statusCode, 403)
        XCTAssertEqual(challenge.rayID, "8f1e2d3c4b5a6978-LHR")
        XCTAssertEqual(challenge.requestMethod, "GET")
    }

    func testHeaderIsCaseInsensitive() throws {
        XCTAssertNotNil(detect(status: 503, headers: ["CF-Mitigated": "Challenge"], body: Data()))
    }

    func testBodyFallbackWithoutHeader() throws {
        let challenge = try XCTUnwrap(detect(
            method: "post",
            status: 503,
            headers: ["Server": "cloudflare"],
            body: fixtureData(named: "cloudflare-challenge")
        ))
        XCTAssertEqual(challenge.requestMethod, "POST")
        XCTAssertNil(challenge.rayID)
    }

    func testServerHeaderAloneIsNotEnough() throws {
        // Cloudflare fronts every Forums response, so an ordinary error page also says Server: cloudflare.
        let mustRegister = try fixtureData(named: "error-must-register")
        let databaseUnavailable = try fixtureData(named: "database-unavailable")
        XCTAssertNil(detect(status: 403, headers: ["Server": "cloudflare"], body: mustRegister))
        XCTAssertNil(detect(status: 503, headers: ["Server": "cloudflare"], body: databaseUnavailable))
    }

    func testBodyMarkersIgnoredOnSuccessStatus() throws {
        // A post quoting challenge markup must not look like a challenge.
        let challengePage = try fixtureData(named: "cloudflare-challenge")
        XCTAssertNil(detect(status: 200, body: challengePage))
    }

    func testHeaderWinsRegardlessOfStatus() throws {
        XCTAssertNotNil(detect(status: 200, headers: ["cf-mitigated": "challenge"], body: Data()))
    }

    func testNonHTTPResponse() {
        let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertNil(CloudflareChallenge(request: URLRequest(url: url), response: response, data: Data()))
    }

    func testIsChallengeResponse() {
        let challenged = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: ["cf-mitigated": "challenge"])!
        let plain = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: ["Server": "cloudflare"])!
        XCTAssertTrue(CloudflareChallenge.isChallengeResponse(challenged))
        XCTAssertFalse(CloudflareChallenge.isChallengeResponse(plain))
    }

    func testCloudflareCookies() throws {
        func cookie(_ name: String) throws -> HTTPCookie {
            try XCTUnwrap(HTTPCookie(properties: [.name: name, .value: "x", .domain: ".somethingawful.com", .path: "/"]))
        }
        XCTAssertTrue(CloudflareChallenge.isCloudflareCookie(try cookie("cf_clearance")))
        XCTAssertTrue(CloudflareChallenge.isCloudflareCookie(try cookie("__cf_bm")))
        XCTAssertTrue(CloudflareChallenge.isCloudflareCookie(try cookie("_cfuvid")))
        XCTAssertFalse(CloudflareChallenge.isCloudflareCookie(try cookie("bbuserid")))
        XCTAssertFalse(CloudflareChallenge.isCloudflareCookie(try cookie("bbpassword")))
    }
}
