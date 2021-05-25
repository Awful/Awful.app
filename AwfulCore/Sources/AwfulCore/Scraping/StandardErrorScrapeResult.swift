//  StandardErrorScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct StandardErrorScrapeResult: ScrapeResult {
    public let title: String
    public let message: String

    public init(_ html: HTMLNode, url: URL?) throws {
        if
            let body = html.firstNode(matchingSelector: "body"),
            body.hasClass("standarderror")
        {
            let standard = body.firstNode(matchingSelector: "#content div.standard")
            
            title = standard?
                .firstNode(matchingSelector: "h2")?
                .textContent
                ?? ""
            
            // We want just enough of an error message so the user knows what's going on. But some of the error messages on the Forums are quite verbose, and unfortunately the markup isn't particularly consistent. This seems to work ok for the errors we have as text fixtures.
            message = standard
                .flatMap { (element: HTMLElement) -> HTMLElement? in element.firstNode(matchingSelector: "div.inner") }
                .flatMap { (element: HTMLElement) -> [HTMLNode]? in Array(element.children.prefix(2)) as? [HTMLNode] }?
                .map { (node: HTMLNode) -> String in node.textContent }
                .joined()
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
                ?? ""
        } else if
            let inner = html.firstNode(matchingSelector: ".standard .inner"),
            inner.textContent.contains("This thread is closed!")
        {
            let altogether = inner.textContent
            if
                let titleEnd = altogether.firstIndex(of: "!"),
                let messageEnd = altogether.lastIndex(of: "!"),
                titleEnd != messageEnd
            {
                title = altogether[...titleEnd].trimmingCharacters(in: .whitespacesAndNewlines)
                message = altogether[titleEnd...messageEnd].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = altogether
                message = ""
            }
        } else {
            throw ScrapingError.missingExpectedElement("body.standarderror, .standard .inner:contains('This thread is closed!')")
        }
    }
}
