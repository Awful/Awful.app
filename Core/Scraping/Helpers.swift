//  Helpers.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

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


internal extension Scanner {
    class func makeForScraping(_ string: String) -> Scanner {
        let scanner = self.init(string: string)
        scanner.charactersToBeSkipped = nil
        scanner.caseSensitive = true
        return scanner
    }

    var remainder: String {
        return String(string.utf16.dropFirst(scanLocation)) ?? ""
    }

    var scanned: String {
        return String(string.utf16.prefix(scanLocation)) ?? ""
    }

    func scanCharacters(from cs: CharacterSet) -> String? {
        var result: NSString?
        guard scanCharacters(from: cs, into: &result) else { return nil }
        return result as String?
    }

    func scanFloat() -> Float? {
        var result: Float = 0
        guard scanFloat(&result) else { return nil }
        return result
    }

    func scanInt() -> Int? {
        var result: Int = 0
        guard scanInt(&result) else { return nil }
        return result
    }

    func scanUpToAndPast(_ s: String) -> Bool {
        scanUpTo(s, into: nil)
        return scanString(s, into: nil)
    }
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
