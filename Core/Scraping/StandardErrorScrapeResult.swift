//
//  StandardErrorScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-27.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

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

        message = standard?
            .firstNode(matchingSelector: "div.inner b:first-of-type")?
            .textContent
            ?? ""
    }
}
