//
//  DatabaseUnavailableScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-27.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import HTMLReader

public struct DatabaseUnavailableScrapeResult: ScrapeResult {
    public let title: String
    public let message: String

    public init(_ html: HTMLNode) throws {
        guard let body = html.firstNode(matchingSelector: "body"), body.hasClass("database_error") else {
            throw ScrapingError.missingExpectedElement("body.database_error")
        }

        let msg = body.firstNode(matchingSelector: "#msg")
        let h1 = msg?.firstNode(matchingSelector: "h1")

        title = h1?.textContent ?? ""

        message = h1
            .flatMap { $0.nextSibling as? HTMLTextNode }
            .map { $0.data }
            ?? ""
    }
}
