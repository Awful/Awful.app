//  StandardErrorScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct StandardErrorScrapeResult: ScrapeResult {
    public let title: String
    public let message: String

    public init(_ html: HTMLNode) throws {
        guard let body = html.firstNode(matchingSelector: "body"), body.hasClass("standarderror") else {
            throw ScrapingError.missingExpectedElement("body.standarderror")
        }

        let standard = body.firstNode(matchingSelector: "#content div.standard")

        title = standard?
            .firstNode(matchingSelector: "h2")?
            .textContent
            ?? ""

        // We want just enough of an error message so the user knows what's going on. But some of the error messages on the Forums are quite verbose, and unfortunately the markup isn't particularly consistent. This seems to work ok for the errors we have as text fixtures.
        message = standard
            .flatMap { $0.firstNode(matchingSelector: "div.inner") }
            .flatMap { Array($0.children.prefix(2)) as? [HTMLNode] }?
            .map { $0.textContent }
            .joined()
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
            ?? ""
    }
}
