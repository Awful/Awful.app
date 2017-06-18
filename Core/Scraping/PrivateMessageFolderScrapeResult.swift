//  PrivateMessageFolderScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct PrivateMessageFolderScrapeResult: ScrapeResult {
    public let allFolders: [Folder]
    public let folder: Folder?
    public let isOnlyShowingLastFiftyMessages: Bool
    public let messages: [Message]

    public struct Folder {
        public let id: PrivateMessageFolderID
        public let name: String
    }

    public struct Message {
        public let hasBeenSeen: Bool
        public let iconDescription: String
        public let iconImage: URL?
        public let id: PrivateMessageID
        public let senderUsername: String
        public let sentDate: Date?
        public let subject: String
        public let wasForwarded: Bool
        public let wasRepliedTo: Bool
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let folderDropdown = html.firstNode(matchingSelector: "select[name = 'folderid']")

        allFolders = folderDropdown?
            .nodes(matchingSelector: "option[value]")
            .flatMap { try? Folder($0) }
            ?? []

        folder = folderDropdown
            .flatMap { $0.firstNode(matchingSelector: "option[selected][value]") }
            .flatMap { try? Folder($0) }

        isOnlyShowingLastFiftyMessages = html
            .firstNode(matchingSelector: "div.pmwarn")?
            .firstNode(matchingSelector: "a[href *= 'showall']")
            != nil

        messages = try html.requiredNode(matchingSelector: "table.standard")
            .nodes(matchingSelector: "tbody tr")
            .flatMap { try? Message($0) }
    }
}

private extension PrivateMessageFolderScrapeResult.Folder {
    init(_ option: HTMLElement) throws {
        assert(option.tagName == "option")

        guard let value = option["value"], let id = PrivateMessageFolderID(rawValue: value) else {
            throw ScrapingError.missingExpectedElement("option[value nonempty]")
        }

        self.id = id

        name = option.textContent
    }
}

private extension PrivateMessageFolderScrapeResult.Message {
    init(_ tr: HTMLElement) throws {
        let subjectLink = try tr.requiredNode(matchingSelector: "td.title a[href]")
        subject = subjectLink.textContent

        guard
            let href = subjectLink["href"],
            let components = URLComponents(string: href),
            let queryItems = components.queryItems,
            let idItem = queryItems.first(where: { $0.name == "privatemessageid" }),
            let rawID = idItem.value,
            let id = PrivateMessageID(rawValue: rawID) else
        {
            throw ScrapingError.missingRequiredValue("privatemessageid")
        }

        self.id = id

        let iconImage = tr.firstNode(matchingSelector: "td.icon img")
        iconDescription = iconImage?["alt"] ?? ""
        self.iconImage = iconImage
            .flatMap { $0["src"] }
            .flatMap { URL(string: $0) }

        senderUsername = tr.firstNode(matchingSelector: "td.sender")?.textContent ?? ""

        sentDate = tr.firstNode(matchingSelector: "td.date")
            .map { $0.textContent }
            .flatMap { twelveHourSentDateFormatter.date(from: $0)
                ?? twentyFourHourSentDateFormatter.date(from: $0) }

        let statusImageSource = tr.firstNode(matchingSelector: "td.status img[src]")?["src"]
        hasBeenSeen = !(statusImageSource?.contains("newpm") ?? false)
        wasForwarded = statusImageSource?.contains("forwarded") ?? false
        wasRepliedTo = statusImageSource?.contains("replied") ?? false
    }
}

private let twelveHourSentDateFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy 'at' h:mm a")
private let twentyFourHourSentDateFormatter = makeScrapingDateFormatter(format: "MMMM d, yyyy 'at' HH:mm")

/// Private message folder IDs sure look numeric but we're gonna treat them as opaque.
public struct PrivateMessageFolderID: Hashable, RawRepresentable {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public static func ==(lhs: PrivateMessageFolderID, rhs: PrivateMessageFolderID) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }
}
