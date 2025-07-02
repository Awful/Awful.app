//  PostScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct PostScrapeResult {
    public let author: AuthorSidebarScrapeResult
    public let authorCanReceivePrivateMessages: Bool
    public let authorIsOriginalPoster: Bool
    public let body: RawHTML
    public let hasBeenSeen: Bool
    public let id: PostID

    /// The original post has index `1`.
    public let indexInThread: Int?

    public let isEditable: Bool
    public let isIgnored: Bool
    public let postDate: Date?
    public let postDateRaw: String?

    public init(_ html: HTMLNode, url: URL?) throws {
        let table = try html.requiredNode(matchingSelector: "table.post[id]")

        do {
            guard let rawestID = table["id"] else {
                throw ScrapingError.missingExpectedElement("table.post[id]")
            }

            let scanner = Scanner(scraping: rawestID)
            _ = scanner.scanString("post")
            guard
                let rawID = scanner.scanCharacters(from: .decimalDigits),
                let id = PostID(rawValue: rawID) else
            {
                throw ScrapingError.missingExpectedElement("table.post[id ^= 'post\\d+']")
            }
            self.id = id
        }

        author = try AuthorSidebarScrapeResult(table, url: url)

        authorCanReceivePrivateMessages = table.firstNode(matchingSelector: "ul.profilelinks a[href *= 'private.php']") != nil

        authorIsOriginalPoster = table.firstNode(matchingSelector: "dt.author.op") != nil

        if let postBody = table.firstNode(matchingSelector: "div.complete_shit") ?? table.firstNode(matchingSelector: "td.postbody") {
            let links = postBody.nodes(matchingSelector: "a[href*='twitter.com']")
            for link in links {
                guard let href = link["href"],
                      let components = URLComponents(string: href),
                      let tweetID = components.path.split(separator: "/").last
                else { continue }
                
                link["data-tweet-id"] = String(tweetID)
            }
            body = postBody.innerHTML
        } else {
            body = ""
        }
        
        hasBeenSeen = table.firstNode(matchingSelector: "tr.seen1")
            ?? table.firstNode(matchingSelector: "tr.seen2")
            != nil

        indexInThread = (table["data-idx"] as String?)
            .flatMap { Int($0) }

        isEditable = table.firstNode(matchingSelector: "ul.postbuttons a[href *= 'editpost.php']") != nil

        isIgnored = table.hasClass("ignored")

        postDateRaw = table
            .firstNode(matchingSelector: "td.postdate")
            .flatMap { $0.children.lastObject as? HTMLNode }
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        
        postDate = postDateRaw
            .flatMap(PostDateFormatter.date(from:))
    }
}
