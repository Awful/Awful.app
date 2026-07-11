//  GlossaryTopicScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// A single SAclopedia ("dictionary.php") topic and its member-contributed entries.
///
/// Scrapes both the random-topic page (`dictionary.php`) and a specific topic
/// (`dictionary.php?act=3&topicid=N`); both render with `<body class="dictionary_show">`.
public struct GlossaryTopicScrapeResult: ScrapeResult {

    /// The topic's title, e.g. "Cougars".
    public let title: String

    /// The topic's numeric ID, recovered from the "Append your information" link. `nil` if the
    /// page didn't include one (e.g. markup change).
    public let topicID: String?

    /// Member contributions, in the order shown on the page.
    public let entries: [Entry]

    public struct Entry: Identifiable, Equatable {
        /// Index within the topic (entries have no stable server-side ID).
        public let id: Int
        public let authorUsername: String
        public let authorUserID: String?
        /// The date exactly as shown, e.g. "June 28, 2005".
        public let postedDateText: String
        /// Inner HTML of the entry body.
        public let bodyHTML: RawHTML
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        title = try body.requiredNode(matchingSelector: "h1.topic")
            .textContent
            .trimmingCharacters(in: .whitespacesAndNewlines)

        topicID = body
            .firstNode(matchingParsedSelector: .cached("a[href*='act=4']"))
            .flatMap { $0["href"] }
            .flatMap { glossaryQueryValue(named: "topicid", inHref: $0) }

        entries = body
            .nodes(matchingParsedSelector: .cached("ul#posts > li"))
            .enumerated()
            .compactMap { index, li in try? Entry(li, id: index) }
    }
}

private extension GlossaryTopicScrapeResult.Entry {
    init(_ html: HTMLElement, id: Int) throws {
        self.id = id

        let byline = try html.requiredNode(matchingSelector: "p.byline")
        let authorLink = byline.firstNode(matchingParsedSelector: .cached("a[href]"))

        authorUsername = authorLink?.textContent.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        authorUserID = authorLink
            .flatMap { $0["href"] }
            .flatMap { glossaryQueryValue(named: "userid", inHref: $0) }

        // Byline reads "Posted by <a>Author</a> on June 28, 2005"; the date is the text node
        // following the author link (falling back to the whole byline if the link is missing).
        let trailing = (authorLink?.nextSibling?.textContent ?? byline.textContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        postedDateText = trailing.hasPrefix("on ")
            ? String(trailing.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            : trailing

        // The body is the entry's paragraph(s) other than the byline.
        let bodyParagraphs = html
            .nodes(matchingParsedSelector: .cached("p"))
            .filter { !$0.hasClass("byline") }
        guard !bodyParagraphs.isEmpty else {
            throw ScrapingError.missingExpectedElement("li p:not(.byline)")
        }
        bodyHTML = bodyParagraphs.map { $0.innerHTML }.joined(separator: "\n")
    }
}

/// Reads a query-item value out of a raw `href` attribute string.
func glossaryQueryValue(named name: String, inHref href: String) -> String? {
    URLComponents(string: href)?.queryItems?.first { $0.name == name }?.value
}
