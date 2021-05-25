//  DatabaseUnavailableScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct DatabaseUnavailableScrapeResult: ScrapeResult {
    public let title: String
    public let message: String

    public init(_ html: HTMLNode, url: URL?) throws {
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
