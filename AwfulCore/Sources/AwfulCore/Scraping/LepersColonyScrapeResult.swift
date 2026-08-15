//  LepersColonyScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

public struct LepersColonyScrapeResult: ScrapeResult {
    public let punishments: [Punishment]

    /// The current page number, when the page's pagination controls could be parsed.
    public let pageNumber: Int?

    /// The total number of pages, when the page's pagination controls could be parsed.
    public let pageCount: Int?

    /// Dynamic options for the "Change Display Options" form, when that form is present. Absent on pages without the form (e.g. a single user's rap sheet).
    public let filterOptions: FilterOptions?

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
        }
    }

    /// Dynamic option lists scraped from the banlist "Change Display Options" form. The type and month filters are static, so they aren't included here.
    public struct FilterOptions: Equatable {
        /// Moderators offered by the `adminid` `<select>`, in document order.
        public let admins: [Admin]

        /// Years offered by the `ban_year` `<select>`, in document order.
        public let years: [Int]
    }

    /// A moderator option in the `adminid` filter.
    public struct Admin: Equatable, Hashable {
        public let id: UserID
        public let username: String

        public init(id: UserID, username: String) {
            self.id = id
            self.username = username
        }
    }

    /// The punishment-type filter (`actfilt`). Raw values are the site's wire values.
    public enum PunishmentFilter: Int, CaseIterable {
        case any = -1
        case probations = 2
        case allBans = -2
        case regularBans = 0
        case autobans = 7
        case permabans = 9
    }

    public init(_ html: HTMLNode, url: URL?) throws {
        let table = try html.requiredNode(matchingSelector: "table.standard")
        punishments = table.nodes(matchingParsedSelector: .cached("tr")).compactMap { try? Punishment($0) }

        let pageNavigation = scrapePageNavigationData(html)
        pageNumber = pageNavigation?.currentPage
        pageCount = pageNavigation?.totalPages

        filterOptions = FilterOptions(html)
    }
}

/// The set of display-filter selections used to request a banlist page. The all-default value is the site's unfiltered view.
public struct LepersColonyFilter: Equatable {
    public var adminID: UserID?
    public var type: LepersColonyScrapeResult.PunishmentFilter
    /// 1...12, or nil for "Any".
    public var month: Int?
    public var year: Int?

    public init(
        adminID: UserID? = nil,
        type: LepersColonyScrapeResult.PunishmentFilter = .any,
        month: Int? = nil,
        year: Int? = nil
    ) {
        self.adminID = adminID
        self.type = type
        self.month = month
        self.year = year
    }
}

private extension LepersColonyScrapeResult.FilterOptions {
    /// Parses the "Change Display Options" form. Returns nil when the `adminid` `<select>` is absent (e.g. a single user's rap sheet page).
    init?(_ html: HTMLNode) {
        guard let adminSelect = html.firstNode(matchingParsedSelector: .cached("select[name='adminid']")) else {
            return nil
        }
        admins = adminSelect
            .nodes(matchingParsedSelector: .cached("option"))
            .compactMap { option in
                guard let id = option["value"].flatMap({ UserID(rawValue: $0) }) else { return nil }
                let username = option.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                return LepersColonyScrapeResult.Admin(id: id, username: username)
            }
        years = html
            .nodes(matchingParsedSelector: .cached("select[name='ban_year'] option"))
            .compactMap { Int($0.textContent.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}

private extension LepersColonyScrapeResult.Punishment {
    init(_ html: HTMLNode) throws {
        let typeCell = try html.requiredNode(matchingSelector: "td:nth-of-type(1)")

        post = typeCell.firstNode(matchingParsedSelector: .cached("a[href]"))
            .flatMap { $0["href"] }
            .flatMap { URLComponents(string: $0) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first(where: { $0.name == "postid" }) }
            .flatMap { $0.value }
            .flatMap { PostID(rawValue: $0) }

        sentence = try? LepersColonyScrapeResult.Punishment.Sentence(typeCell)

        let approverLink = html.firstNode(matchingParsedSelector: .cached("td:nth-of-type(6) a"))
        (approver, approverUsername) = scrapeUserIDAndUsername(approverLink)

        date = html
            .firstNode(matchingParsedSelector: .cached("td:nth-of-type(2)"))
            .map { $0.textContent }
            .flatMap(dateFormatter.date)

        reason = html.firstNode(matchingParsedSelector: .cached("td:nth-of-type(4)"))?.innerHTML ?? ""

        let requesterLink = html.firstNode(matchingParsedSelector: .cached("td:nth-of-type(5) a"))
        (requester, requesterUsername) = scrapeUserIDAndUsername(requesterLink)

        let subjectLink = html.firstNode(matchingParsedSelector: .cached("td:nth-of-type(3) a[href]"))
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

private let dateFormatter = DateFormatter(scraping: "MM/dd/yy hh:mma")

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
