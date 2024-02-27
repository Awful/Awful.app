//  ForumBreadcrumbsScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulModelTypes
import HTMLReader

public struct ForumBreadcrumbsScrapeResult: ScrapeResult {
    public let forums: [ForumBreadcrumb]

    public init(_ html: HTMLNode, url: URL?) throws {
        var breadcrumbs = try html
            .requiredNode(matchingSelector: "div.breadcrumbs")
        
        if (breadcrumbs.childElementNodes.filter { $0.tagName == "span" && $0.hasClass("mainbodytextlarge") }.count > 0) {
            breadcrumbs = try breadcrumbs.requiredNode(matchingSelector: "span.mainbodytextlarge")
        }
        
        forums = try breadcrumbs
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
        guard let a = node as? HTMLElement,
              let href = a["href"],
              let components = URLComponents(string: href),
              let queryItems = components.queryItems,
              let forumIDItem = queryItems.first(where: { $0.name == "forumid" }),
              let rawID = forumIDItem.value
        else { throw ScrapingError.missingExpectedElement("a[href *= 'forumid']") }

        self.id = ForumID(rawValue: rawID)
        name = node.textContent
        self.depth = depth
    }
}
