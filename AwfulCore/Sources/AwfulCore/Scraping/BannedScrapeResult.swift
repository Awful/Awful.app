//  BannedScrapeResult.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct BannedScrapeResult: ScrapeResult {
    public let help: URL?
    public let reason: URL?

    public init(_ html: HTMLNode, url: URL?) throws {
        guard let body = html.firstNode(matchingSelector: "body.banned") else {
            throw ScrapingError.missingExpectedElement("body.banned")
        }

        help = body
            .firstNode(matchingSelector: "a[href*='showthread.php']")
            .flatMap { $0["href"] }
            .flatMap { URL(string: $0) }
        reason = body
            .firstNode(matchingSelector: "a[href*='banlist.php']")
            .flatMap { $0["href"] }
            .flatMap { URL(string: $0) }
    }
}
