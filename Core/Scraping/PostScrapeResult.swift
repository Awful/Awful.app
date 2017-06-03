//
//  PostScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-28.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation
import HTMLReader

public struct PostScrapeResult: ScrapeResult {
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

    public init(_ html: HTMLNode) throws {
        let table = try html.requiredNode(matchingSelector: "table.post[id]")

        do {
            guard let rawestID = table["id"] else {
                throw ScrapingError.missingExpectedElement("table.post[id]")
            }

            let scanner = Scanner.awful_scanner(with: rawestID)
            scanner.scanString("post", into: nil)
            guard
                let rawID = scanner.scanCharacters(from: .decimalDigits),
                let id = PostID(rawValue: rawID) else
            {
                throw ScrapingError.missingExpectedElement("table.post[id ^= 'post\\d+']")
            }
            self.id = id
        }

        author = try AuthorSidebarScrapeResult(table)

        authorCanReceivePrivateMessages = table.firstNode(matchingSelector: "ul.profilelinks a[href *= 'private.php']") != nil

        authorIsOriginalPoster = table.firstNode(matchingSelector: "dt.author.op") != nil

        hasBeenSeen = table.firstNode(matchingSelector: "tr.seen1")
            ?? table.firstNode(matchingSelector: "tr.seen2")
            != nil

        indexInThread = (table["data-idx"] as String?)
            .flatMap { Int($0) }

        isEditable = table.firstNode(matchingSelector: "ul.postbuttons a[href *= 'editpost.php']") != nil

        isIgnored = table.hasClass("ignored")

        postDate = table
            .firstNode(matchingSelector: "td.postdate")
            .flatMap { $0.children.lastObject as? HTMLNode }
            .map { $0.textContent.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(parsePostDate)

        if !isIgnored {
            body = table.firstNode(matchingSelector: "div.complete_shit")?.innerHTML
                ?? table.firstNode(matchingSelector: "td.postbody")?.innerHTML
                ?? ""
        }
        else {
            body = ""
        }
    }
}
