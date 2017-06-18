//  ForumBreadcrumbsScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct ForumBreadcrumbsScrapeResult: ScrapeResult {
    public let forums: [ForumBreadcrumb]

    public init(_ html: HTMLNode, url: URL?) throws {
        forums = try html
            .requiredNode(matchingSelector: "div.breadcrumbs")
            .nodes(matchingSelector: "a[href *= 'forumdisplay.php']")
            .enumerated()
            .map { try ForumBreadcrumb($1, depth: $0) }
    }
}

public struct ForumBreadcrumb: Hashable {
    public let depth: Int
    public let id: ForumID
    public let name: String

    fileprivate init(_ node: HTMLNode, depth: Int) throws {
        guard
            let a = node as? HTMLElement,
            let href = a["href"],
            let components = URLComponents(string: href),
            let queryItems = components.queryItems,
            let forumIDItem = queryItems.first(where: { $0.name == "forumid" }),
            let rawID = forumIDItem.value,
            let id = ForumID(rawValue: rawID) else
        {
            throw ScrapingError.missingExpectedElement("a[href *= 'forumid']")
        }

        self.id = id
        name = node.textContent
        self.depth = depth
    }

    public static func ==(lhs: ForumBreadcrumb, rhs: ForumBreadcrumb) -> Bool {
        return lhs.depth == rhs.depth
            && lhs.id == rhs.id
            && lhs.name == rhs.name
    }

    public var hashValue: Int {
        return id.hashValue
    }
}
