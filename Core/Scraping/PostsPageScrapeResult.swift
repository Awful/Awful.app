//  PostsPageScrapeResult.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import HTMLReader
import class ScannerShim.Scanner

public struct PostsPageScrapeResult: ScrapeResult {
    public let advertisement: RawHTML
    public let breadcrumbs: ForumBreadcrumbsScrapeResult?
    public let forumID: ForumID?
    public let isSingleUserFilterEnabled: Bool
    public let jumpToPostIndex: Int?
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

        let posts = try body
            .nodes(matchingSelector: "table.post")
            .map { (element: HTMLElement) -> PostScrapeResult in try PostScrapeResult(element, url: url) }
        self.posts = posts

        /*
         When jumping to the first unread post in a thread, the URL fragment always indicates a post index on the page (e.g. `#pti1` for the first post on the page).
         Unfortunately, when a post is deleted, the fragment index doesn't change. This can cause us to skip unread posts (`#pti5` when the third post was deleted means we skip over the unread fourth post), or even to attempt a jump to a nonexistest post (`#pti3` when there is only one post remaining in thread).
         A more consistent approach is available when the Forums option "Mark posts on pages I've already seen in a different color" is set to "yes": we can look for the first post that isn't marked. But when that option is set to "no", it's indistinguishable from the user not having seen any of the posts.
         So we'll use the marking when possible, and fall back to the fragment otherwise.
         */
        if let firstUnseen = zip(posts, 0...).first(where: { !$0.0.hasBeenSeen })?.1,
           firstUnseen > 0
        {
            jumpToPostIndex = firstUnseen
        } else {
            jumpToPostIndex = url?.fragment
                .flatMap(parsePti(_:))
                .map { $0 - 1 } // forums index is 1-based, but swift arrays are 0-based
                .flatMap { posts.indices.contains($0) ? $0 : nil }
        }

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

private func parsePti(_ fragment: String) -> Int? {
    let scanner = Scanner(scraping: fragment)
    if scanner.scanString("pti") == nil { return nil }
    return scanner.scanInt()
}
