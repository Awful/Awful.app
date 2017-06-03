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
    public let threadID: ThreadID?
    public let threadIsBookmarked: Bool?
    public let threadIsClosed: Bool
    public let threadTitle: String

    public init(_ html: HTMLNode) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        advertisement = body
            .firstNode(matchingSelector: "#ad_banner_user a")?
            .serializedFragment
            ?? ""

        breadcrumbs = try? ForumBreadcrumbsScrapeResult(body)

        forumID = (body["data-forum"] as String?).flatMap(ForumID.init)

        isSingleUserFilterEnabled = body.firstNode(matchingSelector: "table.post a.user_jump[title *= 'Remove']") != nil

        if let pages = body.firstNode(matchingSelector: "div.pages") {
            let select = pages.firstNode(matchingSelector: "select")

            pageCount = select
                .flatMap { $0.firstNode(matchingSelector: "option:last-of-type[value]") }
                .flatMap { $0["value"] }
                .flatMap { Int($0) }

            pageNumber = select
                .flatMap { $0.firstNode(matchingSelector: "option[selected][value]") }
                .flatMap { $0["value"] }
                .flatMap { Int($0) }
        }
        else {
            pageCount = 1
            pageNumber = 1
        }

        // TODO: calculate indexInThread using perpage and page number (need to pass in URL so we can parse it for perpage)
        posts = try body
            .nodes(matchingSelector: "table.post")
            .map(PostScrapeResult.init)

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
