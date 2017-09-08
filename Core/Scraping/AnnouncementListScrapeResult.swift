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
        let tableBody = html.firstNode(matchingSelector: "table.post tbody")
        let rows = (tableBody?.childElementNodes ?? []).filter { $0.tagName == "tr" }

        let bodyRows = stride(from: rows.startIndex, to: rows.endIndex, by: 2).map { rows[$0] }
        let dateRows = stride(from: rows.index(after: rows.startIndex), to: rows.endIndex, by: 2).map { rows[$0] }

        guard bodyRows.count == dateRows.count else {
            throw ScrapingError.missingExpectedElement("table.post tbody > tr (even count)")
        }

        announcements = try zip(bodyRows, dateRows).map(Announcement.init)
    }
}

private extension AnnouncementListScrapeResult.Announcement {
    init(bodyRow: HTMLNode, dateRow: HTMLNode) throws {
        author = try bodyRow.firstNode(matchingSelector: "dl.userinfo")
            .map(AnnouncementListScrapeResult.Author.init)

        body = try bodyRow.requiredNode(matchingSelector: "td.postbody").innerHTML

        date = dateRow.firstNode(matchingSelector: "td.postdate")
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
