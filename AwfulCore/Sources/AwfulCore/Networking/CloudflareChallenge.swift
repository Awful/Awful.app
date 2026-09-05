//  CloudflareChallenge.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 A Cloudflare "Just a moment…" interstitial that came back instead of a Forums page.

 Cloudflare fronts the whole site, so `Server: cloudflare` is on every response and says nothing. The authoritative signal is the `cf-mitigated: challenge` header, which Cloudflare sets on managed and JavaScript challenges regardless of status code. The body markers are a fallback for the 403/503 cases where that header is missing.
 */
public struct CloudflareChallenge: Sendable, Equatable {

    /// The URL that was challenged (the response URL, i.e. after any redirects).
    public let url: URL

    public let statusCode: Int

    /// The `cf-ray` header, handy for logs and for support requests to Cloudflare.
    public let rayID: String?

    /// The HTTP method of the challenged request. A solved challenge reloads the page as a GET, so a POST's URL is not something worth loading in a web view.
    public let requestMethod: String

    /// Whether the headers alone identify a challenge. Usable where no body is available, e.g. `WKNavigationDelegate`'s response policy decision.
    public static func isChallengeResponse(_ response: HTTPURLResponse) -> Bool {
        guard let mitigated = response.value(forHTTPHeaderField: "cf-mitigated") else { return false }
        return mitigated.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("challenge") == .orderedSame
    }

    /// Cookie names Cloudflare uses for challenge clearance and bot management. These are preserved across logout and copied out of the challenge web view.
    public static func isCloudflareCookie(_ cookie: HTTPCookie) -> Bool {
        let name = cookie.name
        return name == "cf_clearance" || name.hasPrefix("__cf") || name.hasPrefix("_cf")
    }

    /// Status codes Cloudflare serves challenge pages with.
    private static let challengeStatusCodes: Set<Int> = [403, 503]

    /// Strings that only appear in Cloudflare's challenge markup.
    private static let bodyMarkers = [
        "/cdn-cgi/challenge-platform/",
        "_cf_chl_opt",
        "cf-chl",
    ]

    /// Only this much of the body is searched for markers; the challenge page is tiny and a real Forums page is not.
    private static let bodySearchLimit = 64 * 1024

    /// Returns `nil` when the response is not a Cloudflare challenge.
    public init?(request: URLRequest, response: URLResponse, data: Data) {
        guard let http = response as? HTTPURLResponse else { return nil }

        let isChallenge: Bool
        if Self.isChallengeResponse(http) {
            isChallenge = true
        } else if Self.challengeStatusCodes.contains(http.statusCode) {
            let body = String(decoding: data.prefix(Self.bodySearchLimit), as: UTF8.self)
            isChallenge = Self.bodyMarkers.contains { body.contains($0) }
        } else {
            isChallenge = false
        }
        guard isChallenge else { return nil }

        guard let url = http.url ?? request.url else { return nil }
        self.url = url
        statusCode = http.statusCode
        rayID = http.value(forHTTPHeaderField: "cf-ray")
        requestMethod = (request.httpMethod ?? "GET").uppercased()
    }
}
