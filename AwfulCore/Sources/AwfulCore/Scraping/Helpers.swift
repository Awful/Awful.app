//  Helpers.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

func LocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, bundle: Bundle(for: ForumsClient.self), comment: "")
}


extension HTMLNode {
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


extension HTMLElement {
    var classList: [String] {
        (self["class"] ?? "")
            .components(separatedBy: .asciiWhitespace)
            .filter { !$0.isEmpty }
    }
}


extension CharacterSet {
    static var asciiWhitespace: CharacterSet {
        .init(charactersIn: "\t\n\u{000C}\r ")
    }
}


extension DateFormatter {
    convenience init(scraping format: String) {
        self.init()
        locale = Locale(identifier: "en_US_POSIX")
        dateFormat = format
        isLenient = true
    }
}

enum PostDateFormatter {
    private static let twelveHour = DateFormatter(scraping: "MMM d, yyyy h:mm a")
    private static let twentyFourHour = DateFormatter(scraping: "MMM d, yyyy HH:mm")

    static func date(from string: String) -> Date? {
        twelveHour.date(from: string) ?? twentyFourHour.date(from: string)
    }
}

enum RegdateFormatter {
    private static let formatter = DateFormatter(scraping: "MMM d, yyyy")

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}

extension Scanner {
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


func scrapeCustomTitle(_ html: HTMLNode) -> RawHTML? {
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


struct PageNavigationData {
    let currentPage: Int
    let totalPages: Int
    let baseURL: String?
    let perPage: Int?
}

func scrapePageNavigationData(_ node: HTMLNode) -> PageNavigationData? {
    guard let pageDiv = node.firstNode(matchingSelector: "div.pages") else {
        return nil
    }

    if let currentPageStr = pageDiv["data-current-page"],
       let totalPagesStr = pageDiv["data-total-pages"],
       let currentPage = Int(currentPageStr),
       let totalPages = Int(totalPagesStr) {

        let baseURL = pageDiv["data-base-url"]
        let perPage = pageDiv["data-per-page"].flatMap { Int($0) }

        print("[PageNav] Using data attributes: page \(currentPage)/\(totalPages)")

        return PageNavigationData(
            currentPage: currentPage,
            totalPages: totalPages,
            baseURL: baseURL,
            perPage: perPage
        )
    }

    return nil
}

func scrapePageDropdown(_ node: HTMLNode) -> (pageNumber: Int?, pageCount: Int?) {
    guard let pageDiv = node.firstNode(matchingSelector: "div.pages") else {
        return (nil, nil)
    }

    if let currentPageStr = pageDiv["data-current-page"],
       let totalPagesStr = pageDiv["data-total-pages"],
       let currentPage = Int(currentPageStr),
       let totalPages = Int(totalPagesStr) {
        print("[PageNav] Using data attributes: page \(currentPage)/\(totalPages)")
        return (pageNumber: currentPage, pageCount: totalPages)
    }

    // Fallback to old select menu method
    let pageSelect = pageDiv.firstNode(matchingSelector: "select")
    let pageCount = pageSelect?.childElementNodes.count ?? 1

    let pageNumber = pageSelect
        .flatMap { $0.firstNode(matchingSelector: "option[selected]") }
        .flatMap { $0["value"] }
        .flatMap { Int($0) }
        ?? 1

    print("[PageNav] Using select menu fallback: page \(pageNumber)/\(pageCount)")
    return (pageNumber: pageNumber, pageCount: pageCount)
}

enum ForumGroupID: String {
    case archives = "49"
}
