//  GlossaryIndexScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// The SAclopedia ("dictionary.php") list of topics for a single letter
/// (`dictionary.php?act=5&l=CODE`), rendered with `<body class="dictionary_list">`.
public struct GlossaryIndexScrapeResult: ScrapeResult {

    /// The total number of entries across the whole dictionary, parsed from the page heading.
    /// `nil` if the heading didn't advertise a count.
    public let totalEntryCount: Int?

    /// Topics under the requested letter, in the page's (alphabetical) order.
    public let topics: [Topic]

    public struct Topic: Identifiable, Equatable {
        public var id: String { topicID }
        public let title: String
        public let topicID: String
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        totalEntryCount = body
            .firstNode(matchingParsedSelector: .cached("#main_full h2"))
            .map { $0.textContent }
            .flatMap(firstInteger(in:))

        topics = body
            .nodes(matchingParsedSelector: .cached("ul#topiclist > li > a[href]"))
            .compactMap { try? Topic($0) }
    }
}

private extension GlossaryIndexScrapeResult.Topic {
    init(_ html: HTMLElement) throws {
        guard
            let href = html["href"],
            let topicID = glossaryQueryValue(named: "topicid", inHref: href)
        else {
            throw ScrapingError.missingExpectedElement("ul#topiclist a[href*='topicid']")
        }
        self.topicID = topicID
        self.title = html.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Returns the first run of decimal digits in `string` as an `Int`, e.g. 2287 from
/// "SAclopedia - now with 2287 total entries!".
private func firstInteger(in string: String) -> Int? {
    let scanner = Scanner(scraping: string)
    _ = scanner.scanUpToCharacters(from: .decimalDigits)
    return scanner.scanInt()
}
