//  AnnouncementListScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct AnnouncementListScrapeResult: ScrapeResult {
    public let announcements: [Announcement]

    public struct Announcement {
        let author: Author?
        let body: RawHTML
        let date: Date?
    }

    public struct Author {
        public let customTitle: RawHTML
        public let regdate: Date?
        public let username: String
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        announcements = try html
            .nodes(matchingSelector: "table.post")
            .map(Announcement.init)
    }
}

private extension AnnouncementListScrapeResult.Announcement {
    init(_ html: HTMLNode) throws {
        author = try html.firstNode(matchingSelector: "dl.userinfo")
            .map(AnnouncementListScrapeResult.Author.init)

        body = try html.requiredNode(matchingSelector: "td.postbody").innerHTML

        date = html.firstNode(matchingSelector: "td.postdate")
            .map { $0.textContent }
            .flatMap(dateFormatter.date)
    }
}

private extension AnnouncementListScrapeResult.Author {
    init(_ html: HTMLNode) throws {
        customTitle = scrapeCustomTitle(html) ?? ""

        regdate = html
            .firstNode(matchingSelector: "dd.registered")
            .map {$0.textContent }
            .flatMap(regdateFormatter.date)

        username = try html.requiredNode(matchingSelector: "dt.author").textContent
    }
}

private let dateFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy")
