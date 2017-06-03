//  UnreadPrivateMessageCountScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct UnreadPrivateMessageCountScrapeResult: ScrapeResult {
    public let unreadPrivateMessageCount: Int

    public init(_ html: HTMLNode, url: URL?) throws {
        unreadPrivateMessageCount = html
            .nodes(matchingSelector: "table.standard img[src *= 'newpm']")
            .count
    }
}
