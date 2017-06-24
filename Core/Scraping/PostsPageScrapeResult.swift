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

        forumID = (body["data-forum"] as String?).flatMap(ForumID.init)

        isSingleUserFilterEnabled = body.firstNode(matchingSelector: "table.post a.user_jump[title *= 'Remove']") != nil

        (pageNumber: pageNumber, pageCount: pageCount) = scrapePageDropdown(body)

        posts = try body
            .nodes(matchingSelector: "table.post")
            .map { try PostScrapeResult($0, url: url) }

        postsPerPage = url
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
            .flatMap { $0.queryItems }
            .flatMap { $0.first { item in return item.name == "perpage" } }
            .flatMap { $0.value }
            .flatMap { Int($0) }

        threadID = (body["data-thread"] as String?).flatMap(ThreadID.init)

        threadIsBookmarked = body
            .firstNode(matchingSelector: "div.threadbar img.thread_bookmark")
            .flatMap { (img) in
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
