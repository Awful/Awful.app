//  ForumHierarchyScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct ForumHierarchyScrapeResult: ScrapeResult {
    public let nodes: [ForumHierarchyNode]

    public init(_ html: HTMLNode, url: URL?) throws {
        let select = try html.requiredNode(matchingSelector: "select[name = 'forumid']")
        nodes = try select
            .nodes(matchingSelector: "option[value]")
            .flatMap(ForumHierarchyNode.init)
    }
}

public struct ForumHierarchyNode: Hashable {
    /// A `depth` of `0` seems to indicate a "forum group", a forum with subforums but no actual posts of its own, e.g. "Discussion".
    public let depth: Int

    public let id: ForumID
    public let name: String

    public static func == (lhs: ForumHierarchyNode, rhs: ForumHierarchyNode) -> Bool {
        return lhs.depth == rhs.depth
            && lhs.id == rhs.id
            && lhs.name == rhs.name
    }

    public var hashValue: Int {
        return id.hashValue
    }

    /// This is kinda gross. Optional because some <option>s in the dropdown aren't actually for forums. `throws` because we can fail to parse the ones that are forums.
    fileprivate init?(_ html: HTMLElement) throws {
        guard let value = html["value"], html.tagName == "option" else {
            throw ScrapingError.missingExpectedElement("option[value]")
        }

        do {
            let scanner = Scanner.makeForScraping(value)
            guard
                let rawID = scanner.scanCharacters(from: .decimalDigits),
                let id = ForumID(rawValue: rawID)
                else { return nil }
            self.id = id
        }

        do {
            let scanner = Scanner.makeForScraping(html.textContent)
            var depth = 0
            while scanner.scanString("--", into: nil) {
                depth += 1
            }
            self.depth = depth

            _ = scanner.scanCharacters(from: .whitespacesAndNewlines)

            name = scanner.remainder
        }
    }
}
