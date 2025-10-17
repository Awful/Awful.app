//  ThreadListScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulModelTypes
import Foundation
import HTMLReader

public struct ThreadListScrapeResult: ScrapeResult {
    public let announcements: [Announcement]
    public let breadcrumbs: ForumBreadcrumbsScrapeResult?
    public let canPostNewThread: Bool
    public let filterableIcons: [PostIcon]
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

    public struct Thread {
        public let author: UserID?
        public let authorUsername: String
        public let bookmark: Bookmark
        public let icon: PostIcon?
        public let id: ThreadID
        public let isClosed: Bool
        public let isSticky: Bool
        public let isUnread: Bool
        public let lastPostAuthorUsername: String
        public let lastPostDate: Date?
        public let ratingAverage: Float?
        public let ratingCount: Int?
        public let ratingImageBasename: String?

        /// Does not include the original post.
        public let replyCount: Int?

        /// A forum-specific icon alongside the usual icon. Not all forums include this. e.g. Ask/Tell has "Ask" and "Tell" secondary tags.
        public let secondaryIcon: PostIcon?

        public let title: String

        /// Includes the original post.
        public let unreadPostCount: Int?

        public enum Bookmark: Equatable {
            case none
            case orange, red, yellow, cyan, green, purple
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
            .map { links in return links.compactMap { try? PostIcon($0) } }
            ?? []

        forum = (body["data-forum"] as String?)
            .map { ForumID($0) }

        isBookmarkedThreadsPage = body.firstNode(matchingSelector: "form[name='bookmarks']") != nil

        let pageNavData = scrapePageNavigationData(body)
        pageNumber = pageNavData?.currentPage
        pageCount = pageNavData?.totalPages
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

private extension PostIcon {
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

            let scanner = Scanner(scraping: idAttribute)
            _ = scanner.scanUpToCharacters(from: .decimalDigits)
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
            .map { $0.classList }
            .flatMap { $0.lazy
                .compactMap { Bookmark(class: $0) }
                .first { _ in true }
            }
            ?? .none

        let ratingCell = html.firstNode(matchingSelector: "td.rating")

        let iconImage = html.firstNode(matchingSelector: "td.icon")?.firstNode(matchingSelector: "img")
            ?? ratingCell?.firstNode(matchingSelector: "img[src *= '/rate/reviews']")
        
        icon = iconImage.flatMap { try? PostIcon($0) }

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
            .flatMap { $0.firstNode(matchingSelector: "img[title]")?["title"] }
            .map { title in
                let scanner = Scanner(scraping: title)
                _ = scanner.scanUpToCharacters(from: .decimalDigits)
                let count = scanner.scanInt()

                _ = scanner.scanUpToCharacters(from: .decimalDigits)
                let average = scanner.scanFloat()

                return (average, count)
            }
            ?? (nil, nil)
        
        
        ratingImageBasename = ratingCell
            .flatMap { $0.firstNode(matchingSelector: "img[src]")?["src"] }
            .flatMap { URL(string: $0)?.deletingPathExtension().lastPathComponent }

        replyCount = html
            .firstNode(matchingSelector: "td.replies")
            .map { $0.firstNode(matchingSelector: "a") ?? $0 }
            .map { $0.textContent }
            .flatMap { Int($0) }

        secondaryIcon = html.firstNode(matchingSelector: "td.icon2")
            .flatMap { $0.firstNode(matchingSelector: "img") }
            .flatMap { try? PostIcon($0) }

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

private extension ThreadListScrapeResult.Thread.Bookmark {
    init?(class c: String) {
        // There's no single dedicated "bookmarked" class, but there's one for each star color. Assume they all match the same format so we retain bookmarks even as new colors are added.
        guard c.hasPrefix("bm") else { return nil }
        switch Int(c.dropFirst(2)) {
        case 0: self = .orange
        case 1: self = .red
        case 2: self = .yellow
        case 3: self = .cyan
        case 4: self = .green
        case 5: self = .purple
        case .some: self = .orange
        case .none: return nil
        }
    }
}

private let lastPost12DateFormatter = DateFormatter(scraping: "h:mm a MMM d, yyyy")
private let lastPost24DateFormatter = DateFormatter(scraping: "HH:mm MMM d, yyyy")

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
