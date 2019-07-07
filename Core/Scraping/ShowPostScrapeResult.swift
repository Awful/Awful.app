//  ShowPostScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader
import class ScannerShim.Scanner

public struct ShowPostScrapeResult: ScrapeResult {
    public let author: AuthorSidebarScrapeResult
    public let post: PostScrapeResult
    public let threadID: ThreadID?
    public let threadTitle: String

    public init(_ html: HTMLNode, url: URL?) throws {
        author = try AuthorSidebarScrapeResult(html, url: url)

        post = try PostScrapeResult(html, url: url)

        threadID = html.firstNode(matchingSelector: "#thread")
            .flatMap { $0["class"] }
            .flatMap { cls in
                let scanner = Scanner(scraping: cls)
                guard scanner.scanString("thread:") != nil else { return nil }
                return scanner.scanCharacters(from: .decimalDigits)
            }
            .flatMap(ThreadID.init)

        threadTitle = html.firstNode(matchingSelector: "title")
            .flatMap { title in
                let scanner = Scanner(scraping: title.textContent)
                guard scanner.scanUpToAndPastString(" - ") else { return nil }
                return scanner.remainder
            }
            ?? ""
    }
}
