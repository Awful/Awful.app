//  ProfileScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct ProfileScrapeResult: ScrapeResult {
    public let about: RawHTML
    public let aimName: String
    public let author: AuthorSidebarScrapeResult
    public let canReceivePrivateMessages: Bool
    public let gender: String
    public let homepage: URL?
    public let icqName: String
    public let interests: String
    public let lastPostDate: Date?
    public let location: String
    public let occupation: String
    public let postCount: Int?
    public let postRate: String
    public let profilePicture: URL?
    public let yahooName: String

    public init(_ html: HTMLNode) throws {
        author = try AuthorSidebarScrapeResult(html)

        do {
            let infoCell = html.firstNode(matchingSelector: "td.info")

            gender = infoCell
                .flatMap { $0.firstNode(matchingSelector: "p:first-of-type") }
                .map { $0.textContent }
                .flatMap { (info) -> String? in
                    let scanner = Scanner.awful_scanner(with: info)
                    guard scanner.scanUpToAndPast("claims to be a ") else { return nil }
                    return scanner.scanCharacters(from: .letters)
                }
                ?? ""

            about = infoCell
                .flatMap { $0.firstNode(matchingSelector: "p:nth-of-type(2)") }
                .map { $0.innerHTML }
                ?? ""
        }

        do {
            let contactsList = html.firstNode(matchingSelector: "dl.contacts")

            canReceivePrivateMessages = contactsList
                .map { $0.firstNode(matchingSelector: "dt.pm + dd a") != nil }
                ?? false

            aimName = contactsList
                .flatMap { $0.firstNode(matchingSelector: "dt.aim + dd") }
                .flatMap { containsContactInfo($0) ? $0.textContent : nil }
                ?? ""

            icqName = contactsList
                .flatMap { $0.firstNode(matchingSelector: "dt.icq + dd") }
                .flatMap { containsContactInfo($0) ? $0.textContent : nil }
                ?? ""

            yahooName = contactsList
                .flatMap { $0.firstNode(matchingSelector: "dt.yahoo + dd") }
                .flatMap { containsContactInfo($0) ? $0.textContent : nil }
                ?? ""

            homepage = contactsList
                .flatMap { $0.firstNode(matchingSelector: "dt.homepage + dd") }
                .flatMap { $0.firstNode(matchingSelector: "a[href]") }
                .flatMap { $0["href"] }
                .flatMap { URL(string: $0) }
        }

        profilePicture = html
            .firstNode(matchingSelector: "div.userpic img[src]")
            .flatMap { $0["src"] }
            .flatMap { URL(string: $0) }

        do {
            let additionalList = html.firstNode(matchingSelector: "dl.additional")

            postCount = additionalList
                .flatMap { $0.firstNode(matchingSelector: "dd:nth-of-type(2)") }
                .flatMap { $0.children.firstObject as? HTMLNode }
                .map { $0.textContent }
                .flatMap { (text) -> Int? in
                    let scanner = Scanner.awful_scanner(with: text)
                    return scanner.scanInt()
            }

            postRate = additionalList
                .flatMap { $0.firstNode(matchingSelector: "dd:nth-of-type(3)") }
                .flatMap { $0.children.firstObject as? HTMLNode }
                .map { $0.textContent }
                .flatMap { (text) -> String? in
                    let scanner = Scanner.awful_scanner(with: text)
                    guard scanner.scanFloat(nil) else { return nil }
                    return scanner.scanned
                }
                ?? ""

            lastPostDate = additionalList
                .flatMap { $0.firstNode(matchingSelector: "dd:nth-of-type(4)") }
                .flatMap { $0.children.firstObject as? HTMLNode }
                .map { $0.textContent }
                .flatMap(parsePostDate)

            let remainingInfo = additionalList?
                .children
                .flatMap { $0 as? HTMLElement }
                .dropFirst(8)
            var remainingDict: [String: String] = [:]
            var remainingIterator = (remainingInfo ?? []).makeIterator()
            while let dt = remainingIterator.next(), let dd = remainingIterator.next() {
                guard dt.tagName == "dt", dd.tagName == "dd" else { continue }
                remainingDict[dt.textContent] = dd.textContent
            }

            location = remainingDict["Location"] ?? ""
            interests = remainingDict["Interests"] ?? ""
            occupation = remainingDict["Occupation"] ?? ""
        }
    }
}


private func containsContactInfo(_ dd: HTMLElement) -> Bool {
    return dd.firstNode(matchingSelector: "span.unset") == nil
}
