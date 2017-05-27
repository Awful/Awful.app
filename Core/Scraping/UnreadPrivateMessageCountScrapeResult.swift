//
//  UnreadPrivateMessageCountScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-27.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import HTMLReader

public struct UnreadPrivateMessageCountScrapeResult: ScrapeResult {
    public let unreadPrivateMessageCount: Int

    public init(_ html: HTMLNode) throws {
        unreadPrivateMessageCount = html
            .nodes(matchingSelector: "table.standard img[src *= 'newpm']")
            .count
    }
}
