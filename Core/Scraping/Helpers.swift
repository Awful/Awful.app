//  Helpers.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader
import class ScannerShim.Scanner

internal func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, bundle: Bundle(for: ForumsClient.self), comment: "")
}


internal extension HTMLNode {
    var nextSibling: HTMLNode? {
        guard let parent = parent else { return nil }

        let i = parent.index(ofChild: self)
        guard i != UInt(NSNotFound), i + 1 < parent.numberOfChildren else { return nil }

        return parent.child(at: i + 1)
    }

    func requiredNode(matchingSelector selector: String) throws -> HTMLElement {
        guard let node = firstNode(matchingSelector: selector) else {
            throw ScrapingError.missingExpectedElement(selector)
        }
        return node
    }
}


internal func makeScrapingDateFormatter(format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = format
    return formatter
}



private let postDate24HourFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy h:mm a")
private let postDate12HourFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy HH:mm")

internal func parsePostDate(_ string: String) -> Date? {
    return postDate24HourFormatter.date(from: string)
        ?? postDate12HourFormatter.date(from: string)
}


internal let regdateFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy")


internal extension Scanner {
    convenience init(scraping string: String) {
        self.init(string: string)
        charactersToBeSkipped = nil
        caseSensitive = true
    }

    var remainder: String {
        return String(string[currentIndex...])
    }

    var scanned: String {
        return String(string[..<currentIndex])
    }

    func scanUpToAndPastString(_ substring: String) -> Bool {
        _ = scanUpToString(substring)
        return scanString(substring) != nil
    }
}


internal func scrapeCustomTitle(_ html: HTMLNode) -> RawHTML? {
    func isSuperfluousLineBreak(_ node: HTMLNode) -> Bool {
        guard let element = node as? HTMLElement else { return false }
        return element.tagName == "br" && element.hasClass("pb")
    }

    return html
        .firstNode(matchingSelector: "dl.userinfo dd.title")
        .flatMap { $0.children.array as? [HTMLNode] }?
        .filter { !isSuperfluousLineBreak($0) }
        .map { $0.serializedFragment }
        .joined()
}


internal func scrapePageDropdown(_ node: HTMLNode) -> (pageNumber: Int?, pageCount: Int?) {
    let pages = node.firstNode(matchingSelector: "div.pages")
    let pageSelect = pages.flatMap { $0.firstNode(matchingSelector: "select") }

    let pageCount = pageSelect
        .flatMap { $0.firstNode(matchingSelector: "option:last-of-type") }
        .flatMap { $0["value"] }
        .flatMap { Int($0) }
        ?? pages.map { _ in 1 }

    let pageNumber = pageSelect
        .flatMap { $0.firstNode(matchingSelector: "option[selected]") }
        .flatMap { $0["value"] }
        .flatMap { Int($0) }
        ?? pages.map { _ in 1 }

    return (pageNumber: pageNumber, pageCount: pageCount)
}
