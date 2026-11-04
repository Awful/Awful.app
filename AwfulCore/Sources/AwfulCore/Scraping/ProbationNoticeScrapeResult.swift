//  ProbationNoticeScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import Foundation
import HTMLReader

/// The "you are on probation" notice the Forums show near the top of every page while the logged-in user is probated.
public struct ProbationNoticeScrapeResult: ScrapeResult, Equatable, Sendable {
    /// The notice's heading, e.g. "TAKE A BREAK".
    public let title: String

    /// The notice's body text with whitespace collapsed. A new probation has a different message, so this also identifies the probation.
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        // The real notice is a direct child of `#content`. Posts are nested deeper (inside `#thread`), so a copy pasted into a post can't match, and the ancestor check is a second line of defence.
        let selector = "#content > div#probation_warn"
        guard let div = html.firstNode(matchingParsedSelector: .cached(selector)),
              !div.isInsidePostContent
        else { throw ScrapingError.missingExpectedElement(selector) }

        let heading = div.firstNode(matchingParsedSelector: .cached("h4"))
        title = (heading?.textContent ?? "").collapsingWhitespace().trimmingCharacters(in: .whitespaces)
        message = div.children
            .compactMap { $0 as? HTMLNode }
            .filter { $0 !== heading }
            .map(\.textContent)
            .joined()
            .collapsingWhitespace()
            .trimmingCharacters(in: .whitespaces)
    }

    /// When the probation ends, as written by the Forums (e.g. "Nov 3, 2026 22:21"). Not in the user's time zone, so show it verbatim.
    public var endDateText: String? {
        let range = NSRange(message.startIndex..., in: message)
        guard let match = endDateRegex.firstMatch(in: message, range: range),
              let dateRange = Range(match.range(at: 1), in: message)
        else { return nil }
        return String(message[dateRange])
    }
}

private let endDateRegex = try! NSRegularExpression(pattern: "until (.+?)\\.\\s+You cannot post", options: .caseInsensitive)

private extension HTMLElement {
    var isInsidePostContent: Bool {
        var candidate = parentElement
        while let element = candidate {
            switch element.tagName.lowercased() {
            case "table" where element.classList.contains("post"):
                return true
            case "td" where element.classList.contains("postbody"):
                return true
            case "div" where element.classList.contains("complete_shit"):
                return true
            default:
                candidate = element.parentElement
            }
        }
        return false
    }
}
