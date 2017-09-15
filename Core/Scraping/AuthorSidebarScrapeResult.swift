//  AuthorSidebarScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// Scrapes the sidebar with author info that appears alongside posts, private messages, and user profiles.
public struct AuthorSidebarScrapeResult: ScrapeResult {
    public let additionalAuthorClasses: Set<String>
    public let customTitle: RawHTML
    public let isAdministrator: Bool
    public let isModerator: Bool
    public let regdate: Date?
    public let userID: UserID
    public let username: String

    public init(_ html: HTMLNode, url: URL?) throws {
        if
            let profileLink = html.firstNode(matchingSelector: "ul.profilelinks a[href *= 'userid']"),
            let href = profileLink["href"],
            let components = URLComponents(string: href),
            let userIDItem = components.queryItems?.first(where: { $0.name == "userid" }),
            let rawID = userIDItem.value,
            let userID = UserID(rawValue: rawID)
        {
            self.userID = userID
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
            let rawID = userIDInput["value"],
            let userID = UserID(rawValue: rawID)
        {
            self.userID = userID
        }
        else {
            throw ScrapingError.missingRequiredValue("userID")
        }

        let authorTerm = html.firstNode(matchingSelector: "dt.author")
        username = authorTerm?.textContent ?? ""

        var classes = Set((authorTerm?["class"] ?? "")
            .components(separatedBy: .whitespacesAndNewlines))
        isAdministrator = classes.remove("role-admin") != nil
        isModerator = classes.remove("role-mod") != nil
        additionalAuthorClasses = classes

        regdate = html
            .firstNode(matchingSelector: "dd.registered")
            .map { $0.textContent }
            .flatMap(regdateFormatter.date)

        customTitle = scrapeCustomTitle(html) ?? ""
    }
}

private func parseUserID(_ htmlClass: String) -> UserID? {
    let scanner = Scanner.makeForScraping(htmlClass)
    while scanner.scanUpToAndPast("userid-") {
        if
            let id = scanner.scanCharacters(from: .decimalDigits),
            let userID = UserID(rawValue: id)
        {
            return userID
        }
    }
    return nil
}
