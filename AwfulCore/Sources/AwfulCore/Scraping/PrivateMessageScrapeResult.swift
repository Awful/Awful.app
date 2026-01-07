//  PrivateMessageScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct PrivateMessageScrapeResult: ScrapeResult {
    public let author: AuthorSidebarScrapeResult?
    public let body: RawHTML
    public let hasBeenSeen: Bool
    public let privateMessageID: PrivateMessageID
    public let sentDate: Date?
    public let sentDateRaw: String?
    public let subject: String
    public let wasForwarded: Bool
    public let wasRepliedTo: Bool

    public init(_ html: HTMLNode, url: URL?) throws {
        guard
            let replyLink = html.firstNode(matchingSelector: "div.buttons a[href]"),
            let href: String = replyLink["href"],
            let components = URLComponents(string: href),
            let messageIDPair: URLQueryItem = components.queryItems?
                .first(where: { (queryItem: URLQueryItem) -> Bool in queryItem.name == "privatemessageid" }),
            let rawID = messageIDPair.value,
            let privateMessageID = PrivateMessageID(rawValue: rawID) else
        {
            throw ScrapingError.missingRequiredValue("privatemessageid")
        }
        self.privateMessageID = privateMessageID

        author = try? AuthorSidebarScrapeResult(html, url: url)

        subject = html.firstNode(matchingSelector: "div.breadcrumbs b")
            .map { (el: HTMLElement) -> String in
                let fullText = el.textContent
                // Split by " > " separator and take the last component (the subject)
                let components = fullText.components(separatedBy: " > ")
                return components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            ?? ""

        do {
            let postDateCell = html.firstNode(matchingSelector: "td.postdate")

            let iconImageSrc = postDateCell?.firstNode(matchingSelector: "img[src]")
                .flatMap { (el: HTMLElement) -> String? in el["src"] }
            hasBeenSeen = iconImageSrc.map { !$0.contains("newpm") } ?? false
            wasForwarded = iconImageSrc?.contains("forwarded") ?? false
            wasRepliedTo = iconImageSrc?.contains("replied") ?? false

            sentDate = postDateCell
                .flatMap { (cell: HTMLElement) -> HTMLNode? in cell.children.lastObject as? HTMLNode }
                .map { $0.textContent }
                .flatMap(PostDateFormatter.date(from:))
            
            sentDateRaw = postDateCell
                .flatMap { (cell: HTMLElement) -> HTMLNode? in cell.children.lastObject as? HTMLNode }
                .map { $0.textContent }
        }

        body = html.firstNode(matchingSelector: "td.postbody")
            .map { (el: HTMLElement) -> String in el.innerHTML }
            ?? ""
    }
}
