//
//  PrivateMessageScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-28.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation
import HTMLReader

public struct PrivateMessageScrapeResult: ScrapeResult {
    public let author: AuthorSidebarScrapeResult?
    public let body: RawHTML
    public let hasBeenSeen: Bool
    public let privateMessageID: PrivateMessageID
    public let sentDate: Date?
    public let subject: String
    public let wasForwarded: Bool
    public let wasRepliedTo: Bool

    public init(_ html: HTMLNode) throws {
        guard
            let replyLink = html.firstNode(matchingSelector: "div.buttons a[href]"),
            let href = replyLink["href"],
            let components = URLComponents(string: href),
            let messageIDPair = components.queryItems?.first(where: { $0.name == "privatemessageid" }),
            let rawID = messageIDPair.value,
            let privateMessageID = PrivateMessageID(rawValue: rawID) else
        {
            throw ScrapingError.missingRequiredValue("privatemessageid")
        }
        self.privateMessageID = privateMessageID

        author = try? AuthorSidebarScrapeResult(html)

        subject = html.firstNode(matchingSelector: "div.breadcrumbs b")
            .flatMap { $0.children.lastObject as? HTMLTextNode }
            .map { $0.textContent }
            ?? ""

        do {
            let postDateCell = html.firstNode(matchingSelector: "td.postdate")

            let iconImageSrc = postDateCell?.firstNode(matchingSelector: "img[src]")
                .flatMap { $0["src"] }
            hasBeenSeen = iconImageSrc.map { !$0.contains("newpm") } ?? false
            wasForwarded = iconImageSrc?.contains("forwarded") ?? false
            wasRepliedTo = iconImageSrc?.contains("replied") ?? false

            sentDate = postDateCell
                .flatMap { $0.children.lastObject as? HTMLNode }
                .map { $0.textContent }
                .flatMap(parsePostDate)
        }

        body = html.firstNode(matchingSelector: "td.postbody")
            .map { $0.innerHTML }
            ?? ""
    }
}
