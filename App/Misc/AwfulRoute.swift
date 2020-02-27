//  AwfulRoute.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/**
 An `AwfulRoute` is what kids these days call "deep linking": it points to a particular screen in the app.

 `AwfulRoutes`s have many possible sources:

 * Apps that launch other apps via URL, using the `awful:` URL scheme.
 * Handoff.
 * Links that the user taps within the app. e.g. if the user taps a link resembling `https://forums.somethingawful.com/showthread.php?goto=post&postid=000` in a post that points to a user's profile, it's turned into a `.profile(userID:)` route.
 * Pages the user is browsing in Safari, by prepending `awful` to the url to obtain e.g. `awfulhttps://archive.somethingawful.com/showthread.php?threadid=000`.
 * Pasteboard contents when Awful comes to the foreground. If the user copied an Awful-routable URL, they'll be asked if they'd like to open that screen.
 * Within the app itself. e.g. the "Parent Forum" button in the posts screen is implemented by routing a `.forum(id:)` route.

 Use `init(_:) throws` to parse a URL into an `AwfulRoute`.
 */
enum AwfulRoute {

    /// The root of the bookmarks tab.
    case bookmarks

    /// A thread list for a specific forum.
    case forum(id: String)

    /// The root of the Forums tab.
    case forumList

    /// The root of the Leper's Colony tab.
    case lepersColony

    /// A specific message.
    case message(id: String)

    /// The root of the Messages tab.
    case messagesList

    /// A specific post, which probably needs to be located before showing.
    case post(id: String)

    /// A modal presentation of a specific user's profile.
    case profile(userID: String)

    /// A modal presentation of a specific user's rap sheet.
    case rapSheet(userID: String)

    /// The root of the Settings tab.
    case settings

    /// A particular page of posts in a particular thread.
    case threadPage(threadID: String, page: ThreadPage)

    /// A particula rpage of just one user's posts in a particular thread.
    case threadPageSingleUser(threadID: String, userID: String, page: ThreadPage)
}

// MARK: Parsing URLs

extension AwfulRoute {

    init(_ url: URL) throws {
        switch (url.scheme ?? "").caseInsensitive {
        case "awful":
            self = try AwfulRoute.parse(awful: url)

        case "awfulhttp", "awfulhttps", "http", "https":
            self = try AwfulRoute.parse(http: url)

        default:
            throw ParseError.schemeUnknown
        }
    }

    enum ParseError: Error {
        case hostNotSupported
        case invalidPage
        case invalidPath(reason: String)
        case missingForumID
        case missingThreadID
        case missingUserID
        case pathNotSupported
        case schemeUnknown
        case unimplementedAwfulSchemeHost
    }

    private static func parse(awful url: URL) throws -> AwfulRoute {
        let pathComponents = url.pathComponents

        switch url.host ?? "" {
        case "banlist":
            if pathComponents.isEmpty || pathComponents == ["/"] {
                return .lepersColony
            } else if pathComponents.count == 2 {
                return .rapSheet(userID: pathComponents[1])
            } else {
                throw ParseError.invalidPath(reason: "banlist supports at most one path component")
            }

        case "bookmarks":
            if pathComponents.isEmpty || pathComponents == ["/"] {
                return .bookmarks
            } else {
                throw ParseError.invalidPath(reason: "bookmarks doesn't support a path")
            }

        case "forums":
            if pathComponents.isEmpty || pathComponents == ["/"] {
                return .forumList
            } else if pathComponents.count == 2 {
                return .forum(id: pathComponents[1])
            } else {
                throw ParseError.invalidPath(reason: "forums supports at most one path component")
            }

        case "messages":
            if pathComponents.isEmpty || pathComponents == ["/"] {
                return .messagesList
            } else {
                throw ParseError.invalidPath(reason: "messages supports at most one path component")
            }

        case "posts":
            if pathComponents.count == 2 {
                return .post(id: pathComponents[1])
            } else {
                throw ParseError.invalidPath(reason: "posts requires exactly one path component")
            }

        case "settings":
            if pathComponents.isEmpty || pathComponents == ["/"] {
                return .settings
            } else {
                throw ParseError.invalidPath(reason: "settings doesn't support a path")
            }

        case "threads":
            guard pathComponents.count >= 2 else {
                throw ParseError.invalidPath(reason: "threads needs a thread ID")
            }
            let threadID = pathComponents[1]
            let userID = url.valueForFirstQueryItem(named: "userid")

            let page: ThreadPage
            if pathComponents.count == 4, pathComponents[2] == "pages" {
                let rawPage = pathComponents[3]
                if rawPage.caseInsensitive == "last" {
                    page = .last
                } else if rawPage.caseInsensitive == "unread" {
                    page = .nextUnread
                } else if let number = Int(rawPage), number > 0 {
                    page = .specific(number)
                } else {
                    throw ParseError.invalidPage
                }
            } else if pathComponents.count == 2 {
                page = .first
            } else {
                throw ParseError.invalidPath(reason: "threads only supports an optional page number")
            }

            if let userID = userID, userID != "0" {
                return .threadPageSingleUser(threadID: threadID, userID: userID, page: page)
            } else {
                return .threadPage(threadID: threadID, page: page)
            }

        case "users":
            if pathComponents.count == 2 {
                return .profile(userID: pathComponents[1])
            } else {
                throw ParseError.invalidPath(reason: "users requires (and only supports) a user ID")
            }

        default:
            throw ParseError.unimplementedAwfulSchemeHost
        }
    }

    private static func parse(http url: URL) throws -> AwfulRoute {

        // Any arbitrary HTTP URL might get thrown at us, but we really only know how to handle SA Forums URLs.
        switch (url.host ?? "").caseInsensitive {
        case "archives.somethingawful.com",
             "forums.somethingawful.com":
            break

        default:
            throw ParseError.hostNotSupported
        }


        switch url.path.caseInsensitive {
        case "/banlist.php":
            if let userID = url.valueForFirstQueryItem(named: "userid"), !userID.isEmpty {
                return .rapSheet(userID: userID)
            } else {
                return .lepersColony
            }

        case "/forumdisplay.php":
            guard let forumID = url.valueForFirstQueryItem(named: "forumid"), !forumID.isEmpty else {
                throw ParseError.missingForumID
            }
            return .forum(id: forumID)

        case "/member.php":
            guard let userID = url.valueForFirstQueryItem(named: "userid"), !userID.isEmpty else {
                throw ParseError.missingUserID
            }
            return .profile(userID: userID)

        case "/showthread.php":

            // A specific post in an unknown thread. Post ID can come via query item or in the fragment.
            if
                let postID = url.valueForFirstQueryItem(named: "postid"),
                !postID.isEmpty,
                url.valueForFirstQueryItem(named: "goto") == "post"
                    || url.valueForFirstQueryItem(named: "action") == "showpost"
            {
                return .post(id: postID)
            }
            if let fragment = url.fragment, fragment.hasPrefix("post"), fragment.count > 4 {
                let start = fragment.index(fragment.startIndex, offsetBy: 4)
                let postID = String(fragment[start...])
                return .post(id: postID)
            }

            // Rest of the routes here are specific to a thread, which has a thread ID.
            guard let threadID = url.valueForFirstQueryItem(named: "threadid"), !threadID.isEmpty else {
                throw ParseError.missingThreadID
            }

            // If a user ID is present, it means to show only that user's posts.
            let userID = url.valueForFirstQueryItem(named: "userid")

            // Page numbers must be at least 1. If missing or invalid, assume page 1.
            let page: ThreadPage
            if
                let rawPage = url.valueForFirstQueryItem(named: "pagenumber"),
                let number = Int(rawPage),
                number > 0
            {
                page = .specific(number)
            } else {
                page = .first
            }

            // The Forums takes a user ID of `0` to mean "no user".
            if let userID = userID, userID != "0" {
                return .threadPageSingleUser(threadID: threadID, userID: userID, page: page)
            } else {
                return .threadPage(threadID: threadID, page: page)
            }

        default:
            throw ParseError.pathNotSupported
        }
    }
}

// MARK: Making URLs

private let baseURL = URL(string: "https://forums.somethingawful.com/")!

extension AwfulRoute {
    var httpURL: URL {
        var components = URLComponents()
        switch self {
        case .bookmarks:
            components.path = "bookmarkthreads.php"

        case .forum(let id):
            components.path = "forumdisplay.php"
            components.queryItems = [URLQueryItem(name: "forumid", value: id)]

        case .forumList:
            break

        case .lepersColony:
            components.path = "banlist.php"

        case .message(let id):
            components.path = "private.php"
            components.queryItems = [
                URLQueryItem(name: "action", value: "show"),
                URLQueryItem(name: "privatemessageid", value: id)]

        case .messagesList:
            components.path = "private.php"

        case .post(let id):
            components.path = "showthread.php"
            components.queryItems = [
                URLQueryItem(name: "goto", value: "post"),
                URLQueryItem(name: "postid", value: id)]

        case .profile(let userID):
            components.path = "member.php"
            components.queryItems = [
                URLQueryItem(name: "action", value: "getinfo"),
                URLQueryItem(name: "userid", value: userID)]

        case .rapSheet(let userID):
            components.path = "banlist.php"
            components.queryItems = [URLQueryItem(name: "userid", value: userID)]

        case .settings:
            components.path = "usercp.php"

        case .threadPage(let threadID, let page):
            components.path = "showthread.php"
            components.queryItems = [
                URLQueryItem(name: "threadid", value: threadID),
                URLQueryItem(name: "perpage", value: "40"),
                page.queryItem]

        case .threadPageSingleUser(let threadID, let userID, let page):
            components.path = "showthread.php"
            components.queryItems = [
                URLQueryItem(name: "threadid", value: threadID),
                URLQueryItem(name: "perpage", value: "40"),
                page.queryItem,
                URLQueryItem(name: "userid", value: userID)]
        }
        return components.url(relativeTo: baseURL)!
    }
}

private extension ThreadPage {
    var queryItem: URLQueryItem {
        switch self {
        case .last:
            return .init(name: "goto", value: "lastpost")
        case .nextUnread:
            return .init(name: "goto", value: "newpost")
        case .specific(let number):
            return .init(name: "pagenumber", value: "\(number)")
        }
    }
}
