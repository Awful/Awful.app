//  PostsPageScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader

public struct PostsPageScrapeResult: ScrapeResult {
    public let advertisement: RawHTML
    public let breadcrumbs: ForumBreadcrumbsScrapeResult?
    public let forumID: ForumID?
    public let isSingleUserFilterEnabled: Bool
    public let pageCount: Int?
    public let pageNumber: Int?
    public let posts: [PostScrapeResult]
    public let postsPerPage: Int?
    public let threadID: ThreadID?
    public let threadIsBookmarked: Bool?
    public let threadIsClosed: Bool
    public let threadTitle: String

    public init(_ html: HTMLNode, url: URL?) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        advertisement = body
            .firstNode(matchingSelector: "#ad_banner_user a")?
            .serializedFragment
            ?? ""

        breadcrumbs = try? ForumBreadcrumbsScrapeResult(body, url: url)

        forumID = (body["data-forum"] as String?).flatMap { ForumID(rawValue: $0) }

        isSingleUserFilterEnabled = body.firstNode(matchingSelector: "table.post a.user_jump[title *= 'Remove']") != nil

        (pageNumber: pageNumber, pageCount: pageCount) = scrapePageDropdown(body)

        posts = try body
            .nodes(matchingSelector: "table.post")
            .map { (element: HTMLElement) -> PostScrapeResult in try PostScrapeResult(element, url: url) }

        postsPerPage = url
            .flatMap { (url: URL) -> URLComponents? in URLComponents(url: url, resolvingAgainstBaseURL: true) }
            .flatMap { (components: URLComponents) -> [URLQueryItem]? in components.queryItems }
            .flatMap { (queryItems: [URLQueryItem]) -> URLQueryItem? in queryItems.first { item in return item.name == "perpage" } }
            .flatMap { (queryItem: URLQueryItem) -> String? in queryItem.value }
            .flatMap { (value: String) -> Int? in Int(value) }

        threadID = (body["data-thread"] as String?).flatMap { ThreadID(rawValue: $0) }

        threadIsBookmarked = body
            .firstNode(matchingSelector: "div.threadbar img.thread_bookmark")
            .flatMap { (img) -> Bool? in
                switch (img.hasClass("unbookmark"), img.hasClass("bookmark")) {
                case (true, false): return true
                case (false, true): return false
                default: return nil
                }
        }

        threadIsClosed = body.firstNode(matchingSelector: "ul.postbuttons a[href *= 'newreply'] img[src *= 'closed']") != nil

        threadTitle = body
            .firstNode(matchingSelector: "div.breadcrumbs a[href *= 'threadid']")?
            .textContent
            ?? ""
    }
}
