//  LepersColonyScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct LepersColonyScrapeResult: ScrapeResult {
    public let punishments: [Punishment]

    public struct Punishment: Hashable {
        public let approver: UserID?
        public let approverUsername: String
        public let date: Date?
        public let post: PostID?
        public let reason: RawHTML
        public let requester: UserID?
        public let requesterUsername: String
        public let sentence: Sentence?
        public let subject: UserID?
        public let subjectUsername: String

        public enum Sentence: Equatable {
            case probation, ban, autoban, permaban

            public var isBan: Bool {
                switch self {
                case .probation:
                    return false

                case .ban, .autoban, .permaban:
                    return true
                }
            }

            public static func == (lhs: Sentence, rhs: Sentence) -> Bool {
                switch (lhs, rhs) {
                case (.probation, .probation), (.ban, .ban), (.autoban, .autoban), (.permaban, .permaban):
                    return true
                case (.probation, _), (.ban, _), (.autoban, _), (.permaban, _):
                    return false
                }
            }
        }

        public static func == (lhs: Punishment, rhs: Punishment) -> Bool {
            return lhs.approver == rhs.approver
                && lhs.approverUsername == rhs.approverUsername
                && lhs.date == rhs.date
                && lhs.post == rhs.post
                && lhs.reason == rhs.reason
                && lhs.requester == rhs.requester
                && lhs.requesterUsername == rhs.requesterUsername
                && lhs.sentence == rhs.sentence
                && lhs.subject == rhs.subject
                && lhs.subjectUsername == rhs.subjectUsername
        }

        public var hashValue: Int {
            return subjectUsername.hashValue
        }
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let table = try html.requiredNode(matchingSelector: "table.standard")
        punishments = table.nodes(matchingSelector: "tr").flatMap { try? Punishment($0) }
    }
}

private extension LepersColonyScrapeResult.Punishment {
    init(_ html: HTMLNode) throws {
        let typeCell = try html.requiredNode(matchingSelector: "td:nth-of-type(1)")

        post = typeCell.firstNode(matchingSelector: "a[href]")
            .flatMap { $0["href"] }
            .flatMap { URLComponents(string: $0) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first(where: { $0.name == "postid" }) }
            .flatMap { $0.value }
            .flatMap { PostID(rawValue: $0) }

        sentence = try? LepersColonyScrapeResult.Punishment.Sentence(typeCell)

        let approverLink = html.firstNode(matchingSelector: "td:nth-of-type(6) a")
        (approver, approverUsername) = scrapeUserIDAndUsername(approverLink)

        date = html
            .firstNode(matchingSelector: "td:nth-of-type(2)")
            .map { $0.textContent }
            .flatMap(dateFormatter.date)

        reason = html.firstNode(matchingSelector: "td:nth-of-type(4)")?.innerHTML ?? ""

        let requesterLink = html.firstNode(matchingSelector: "td:nth-of-type(5) a")
        (requester, requesterUsername) = scrapeUserIDAndUsername(requesterLink)

        let subjectLink = html.firstNode(matchingSelector: "td:nth-of-type(3) a[href]")
        (subject, subjectUsername) = scrapeUserIDAndUsername(subjectLink)
    }
}

private extension LepersColonyScrapeResult.Punishment.Sentence {
    init(_ html: HTMLElement) throws {
        let text = html.textContent
        if text.contains("PROBATION") {
            self = .probation
        }
        else if text.contains("AUTOBAN") {
            self = .autoban
        }
        else if text.contains("PERMABAN") {
            self = .permaban
        }
        else if text.contains("BAN") {
            self = .ban
        }
        else {
            throw ScrapingError.missingRequiredValue("PROBATION, AUTOBAN, PERMABAN, or BAN")
        }
    }
}

private let dateFormatter = makeScrapingDateFormatter(format: "MM/dd/yy hh:mma")

private func scrapeUserIDAndUsername(_ a: HTMLElement?) -> (id: UserID?, username: String) {
    let id = a
        .flatMap { $0["href"] }
        .flatMap { URLComponents(string: $0) }
        .flatMap { $0.queryItems }
        .flatMap { $0.first(where: { $0.name == "userid" }) }
        .flatMap { $0.value }
        .flatMap { UserID(rawValue: $0) }

    return (id: id, username: a?.textContent ?? "")
}
