//  ThreadListScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct ThreadListScrapeResult: ScrapeResult {
    public let announcements: [Announcement]
    public let breadcrumbs: ForumBreadcrumbsScrapeResult?
    public let canPostNewThread: Bool
    public let filterableIcons: [Icon]
    public let forum: ForumID?
    public let isBookmarkedThreadsPage: Bool
    public let pageCount: Int?
    public let pageNumber: Int?
    public let threads: [Thread]

    public struct Announcement {
        public let author: UserID?
        public let authorUsername: String
        public let lastUpdated: Date?
        public let iconURL: URL?
        public let title: String
    }

    public struct Icon {
        public let id: String
        public let url: URL?
    }

    public struct Thread {
        public let author: UserID?
        public let authorUsername: String
        public let bookmark: Bookmark
        public let icon: Icon?
        public let id: ThreadID
        public let isClosed: Bool
        public let isSticky: Bool
        public let isUnread: Bool
        public let lastPostAuthorUsername: String
        public let lastPostDate: Date?
        public let ratingAverage: Float?
        public let ratingCount: Int?

        /// Does not include the original post.
        public let replyCount: Int?

        /// A forum-specific icon alongside the usual icon. Not all forums include this. e.g. Ask/Tell has "Ask" and "Tell" secondary tags.
        public let secondaryIcon: Icon?

        public let title: String

        /// Includes the original post.
        public let unreadPostCount: Int?

        public enum Bookmark: Equatable {
            case none, orange, red, yellow

            public static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
                switch (lhs, rhs) {
                case (.none, .none), (.orange, .orange), (.red, .red), (.yellow, .yellow):
                    return true

                case (.none, _), (.orange, _), (.red, _), (.yellow, _):
                    return false
                }
            }
        }
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        (announcements, threads) = scrapeAnnouncementsAndThreads(body.nodes(matchingSelector: "tr.thread"))

        breadcrumbs = try? ForumBreadcrumbsScrapeResult(body, url: url)

        canPostNewThread = body
            .firstNode(matchingSelector: "ul.postbuttons")
            .flatMap { $0.firstNode(matchingSelector: "a[href*='newthread']") }
            != nil

        filterableIcons = body
            .firstNode(matchingSelector: "div.thread_tags")
            .map { $0.nodes(matchingSelector: "a[href*='posticon']") }
            .map { links in return links.flatMap { try? Icon($0) } }
            ?? []

        forum = (body["data-forum"] as String?)
            .flatMap { ForumID(rawValue: $0) }

        isBookmarkedThreadsPage = body.firstNode(matchingSelector: "form[name='bookmarks']") != nil

        let pages = body.firstNode(matchingSelector: "div.pages")
        let pageSelect = pages.flatMap { $0.firstNode(matchingSelector: "select") }

        pageCount = pageSelect
            .flatMap { $0.firstNode(matchingSelector: "option:last-of-type") }
            .flatMap { $0["value"] }
            .flatMap { Int($0) }
            ?? pages.map { _ in 1 }

        pageNumber = pageSelect
            .flatMap { $0.firstNode(matchingSelector: "option[selected]") }
            .flatMap { $0["value"] }
            .flatMap { Int($0) }
            ?? pages.map { _ in 1 }
    }
}

private extension ThreadListScrapeResult.Announcement {
    init(_ html: HTMLElement) throws {
        let authorLink = html
            .firstNode(matchingSelector: "td.author")
            .flatMap { $0.firstNode(matchingSelector: "a[href]") }

        author = authorLink
            .flatMap { $0["href"] }
            .flatMap { URLComponents(string: $0) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first(where: { $0.name == "userid" }) }
            .flatMap { $0.value }
            .flatMap { UserID(rawValue: $0) }

        authorUsername = authorLink?.textContent ?? ""

        lastUpdated = html
            .firstNode(matchingSelector: "td.lastpost")
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(parseLastPostDate)

        iconURL = html
            .firstNode(matchingSelector: "td.icon")
            .flatMap { $0.firstNode(matchingSelector: "img[src]") }
            .flatMap { $0["src"] }
            .flatMap { URL(string: $0) }

        title = html
            .firstNode(matchingSelector: "td.title")
            .flatMap { $0.firstNode(matchingSelector: "a") }
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? ""
    }
}

private extension ThreadListScrapeResult.Icon {
    init(_ html: HTMLElement) throws {
        let idFromLink = html
            .firstNode(matchingSelector: "a[href]")
            .flatMap { $0["href"] }
            .flatMap { URLComponents(string: $0) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first(where: { $0.name == "posticon" }) }
            .flatMap { $0.value }


        guard
            let img = html.firstNode(matchingSelector: "img"),
            let src = img["src"],
            let url = URL(string: src) else
        {
            throw ScrapingError.missingExpectedElement("img[src=url]")
        }

        id = idFromLink ?? url.fragment ?? ""
        self.url = url
    }
}

private extension ThreadListScrapeResult.Thread {
    init(_ html: HTMLElement) throws {
        do {
            guard let idAttribute = html["id"] else {
                throw ScrapingError.missingExpectedElement("tr[id]")
            }

            let scanner = Scanner.makeForScraping(idAttribute)
            scanner.scanUpToCharacters(from: .decimalDigits, into: nil)
            guard
                let rawID = scanner.scanCharacters(from: .decimalDigits),
                let id = ThreadID(rawValue: rawID) else
            {
                throw ScrapingError.missingExpectedElement("tr[id=decimalDigits]")
            }
            self.id = id
        }

        let authorLink = html
            .firstNode(matchingSelector: "td.author")
            .flatMap { $0.firstNode(matchingSelector: "a") }

        author = authorLink
            .flatMap { $0["href"] }
            .flatMap { URLComponents(string: $0) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first(where: { $0.name == "userid" }) }
            .flatMap { $0.value }
            .flatMap { UserID(rawValue: $0) }

        authorUsername = authorLink?.textContent ?? ""

        bookmark = html
            .firstNode(matchingSelector: "td.star")
            .map { td in
                if td.hasClass("bm0") {
                    return .orange
                }
                else if td.hasClass("bm1") {
                    return .red
                }
                else if td.hasClass("bm2") {
                    return .yellow
                }
                else {
                    return .none
                }
            }
            ?? .none

        let ratingCell = html.firstNode(matchingSelector: "td.rating")

        let iconImage = html.firstNode(matchingSelector: "td.icon")?.firstNode(matchingSelector: "img")
            ?? ratingCell?.firstNode(matchingSelector: "img[src *= '/rate/reviews']")
        icon = iconImage.flatMap { try? ThreadListScrapeResult.Icon($0) }

        isClosed = html.hasClass("closed")

        let titleCell = html.firstNode(matchingSelector: "td.title")

        isSticky = titleCell?.hasClass("title_sticky") ?? false

        let lastSeen = titleCell?.firstNode(matchingSelector: "div.lastseen")

        isUnread = lastSeen?.firstNode(matchingSelector: "a.x") == nil

        let lastPostCell = html.firstNode(matchingSelector: "td.lastpost")

        lastPostAuthorUsername = lastPostCell
            .flatMap { $0.firstNode(matchingSelector: "a.author") }
            .map { $0.textContent }
            ?? ""

        lastPostDate = lastPostCell
            .flatMap { $0.firstNode(matchingSelector: "div.date") }
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(parseLastPostDate)

        (ratingAverage, ratingCount) = ratingCell
            .flatMap { $0.firstNode(matchingSelector: "img[title]") }
            .flatMap { $0["title"] }
            .map { title in
                let scanner = Scanner.makeForScraping(title)
                scanner.scanUpToCharacters(from: .decimalDigits, into: nil)
                let count = scanner.scanInt()

                scanner.scanUpToCharacters(from: .decimalDigits, into: nil)
                let average = scanner.scanFloat()

                return (average, count)
            }
            ?? (nil, nil)

        replyCount = html
            .firstNode(matchingSelector: "td.replies")
            .map { $0.firstNode(matchingSelector: "a") ?? $0 }
            .map { $0.textContent }
            .flatMap { Int($0) }

        secondaryIcon = html.firstNode(matchingSelector: "td.icon2")
            .flatMap { $0.firstNode(matchingSelector: "img") }
            .flatMap { try? ThreadListScrapeResult.Icon($0) }

        title = titleCell
            .flatMap { $0.firstNode(matchingSelector: "a.thread_title") }
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? ""

        unreadPostCount = lastSeen
            .flatMap { $0.firstNode(matchingSelector: "a.count") }
            .flatMap { $0.firstNode(matchingSelector: "b") }
            .map { $0.textContent }
            .flatMap { Int($0) }
    }
}

private let lastPost12DateFormatter = makeScrapingDateFormatter(format: "h:mm a MMM d, yyyy")
private let lastPost24DateFormatter = makeScrapingDateFormatter(format: "HH:mm MMM d, yyyy")

private func parseLastPostDate(_ s: String) -> Date? {
    return lastPost12DateFormatter.date(from: s)
        ?? lastPost24DateFormatter.date(from: s)
}

private func scrapeAnnouncementsAndThreads(_ rows: [HTMLElement])
    -> (announcements: [ThreadListScrapeResult.Announcement], threads: [ThreadListScrapeResult.Thread])
{
    var announcements: [ThreadListScrapeResult.Announcement] = []
    var threads: [ThreadListScrapeResult.Thread] = []

    for row in rows {
        if
            let title = row.firstNode(matchingSelector: "td.title"),
            title.firstNode(matchingSelector: "a.announcement") != nil
        {
            if let announcement = try? ThreadListScrapeResult.Announcement(row) {
                announcements.append(announcement)
            }
        }
        else {
            if let thread = try? ThreadListScrapeResult.Thread(row) {
                threads.append(thread)
            }
        }
    }

    return (announcements: announcements, threads: threads)
}
