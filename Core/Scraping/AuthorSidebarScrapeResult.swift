//
//  AuthorSidebarScrapeResult.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation

/// Scrapes the sidebar with author info that appears alongside posts, private messages, and user profiles.
public struct AuthorSidebarScrapeResult: ScrapeResult {
    public let additionalAuthorClasses: Set<String>
    public let customTitle: RawHTML
    public let isAdministrator: Bool
    public let isModerator: Bool
    public let regdate: Date?
    public let userID: UserID
    public let username: String

    public init(_ html: HTMLNode) throws {
        if
            let profileLink = html.firstNode(matchingSelector: "ul.profilelinks a[href *= 'userid']"),
            let href = profileLink["href"],
            let components = URLComponents(string: href),
            let userIDItem = components.queryItems?.first(where: { $0.name == "userid" }),
            let userID = userIDItem.value
        {
            self.userID = UserID(rawValue: userID)
        }
        else if
            let userInfo = html.firstNode(matchingSelector: "td.userinfo"),
            let htmlClass = userInfo["class"],
            let userID = parseUserID(htmlClass)
        {
            self.userID = userID
        }
        else if
            let userIDInput = html.firstNode(matchingSelector: "input[name = 'userid']"),
            let userID = userIDInput["value"]
        {
            self.userID = UserID(rawValue: userID)
        }
        else {
            userID = UserID(rawValue: "")
        }

        let authorTerm = html.firstNode(matchingSelector: "dt.author")
        username = authorTerm?.textContent ?? ""

        if userID.isEmpty, username.isEmpty {
            throw ScrapingError.missingRequiredValue("userID or username")
        }

        var classes = Set((authorTerm?["class"] ?? "")
            .components(separatedBy: .whitespacesAndNewlines))
        isAdministrator = classes.remove("role-admin") != nil
        isModerator = classes.remove("role-mod") != nil
        additionalAuthorClasses = classes

        regdate = html
            .firstNode(matchingSelector: "dd.registered")
            .map { $0.textContent }
            .flatMap(regdateFormatter.date)

        customTitle = RawHTML(rawValue: html
            .firstNode(matchingSelector: "dl.userinfo dd.title")
            .flatMap { $0.children.array as? [HTMLNode] }?
            .filter { !isSuperfluousLineBreak($0) }
            .map { $0.serializedFragment }
            .joined()
            ?? "")
    }
}

private func isSuperfluousLineBreak(_ node: HTMLNode) -> Bool {
    guard let element = node as? HTMLElement else { return false }
    return element.tagName == "br" && element.hasClass("pb")
}

private func parseUserID(_ htmlClass: String) -> UserID? {
    let scanner = Scanner.awful_scanner(with: htmlClass)
    while scanner.scanUpToAndPast("userid-") {
        if let id = scanner.scanCharacters(from: .decimalDigits) {
            return UserID(rawValue: id)
        }
    }
    return nil
}

private let regdateFormatter = makeScrapingDateFormatter(format: "MMM d, yyyy")
