//  ThreadPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension ThreadListScrapeResult {
    func upsert(
        into context: NSManagedObjectContext
    ) throws -> [AwfulThread] {
        let (group: _, forums: forums) = try breadcrumbs?.upsert(into: context) ?? (nil, [])
        let forum = forums.last

        let icons = self.threads.compactMap { $0.icon }
            + self.threads.compactMap { $0.secondaryIcon }
            + self.filterableIcons
        let iconHelper = PostIconPersistenceHelper(context: context, icons: icons)
        iconHelper.performFetch()
        
        forum?.threadTags = NSMutableOrderedSet(array: filterableIcons.map { iconHelper.upsert($0) })

        var users = Dictionary(
            User.fetch(in: context, configure: { request in
                let userIDs = self.threads.compactMap { $0.author?.rawValue }
                request.predicate = .init("\(\User.userID) IN \(userIDs)")
                request.returnsObjectsAsFaults = false
            }).map { (UserID(rawValue: $0.userID)!, $0) },
            uniquingKeysWith: { $1 }
        )
        let existingThreads = Dictionary(
            AwfulThread.fetch(in: context) { request in
                let threadIDs = self.threads.map { $0.id.rawValue }
                request.predicate = .init("\(\AwfulThread.threadID) IN \(threadIDs)")
                request.returnsObjectsAsFaults = false
            }.map { (ThreadID(rawValue: $0.threadID)!, $0) },
            uniquingKeysWith: { $1 }
        )

        var threads: [AwfulThread] = []
        var stickyIndex = -self.threads.count
        for raw in self.threads {
            let thread = existingThreads[raw.id] ?? AwfulThread.insert(into: context)

            raw.update(thread)

            if let authorID = raw.author {
                let author = users[authorID] ?? {
                    let author = User.insert(into: context)
                    author.userID = authorID.rawValue
                    users[authorID] = author
                    return author
                }()

                if !raw.authorUsername.isEmpty, raw.authorUsername != author.username { author.username = raw.authorUsername }

                if author != thread.author { thread.author = author }
            }

            if let pageNumber = pageNumber {
                if isBookmarkedThreadsPage {
                    if pageNumber != Int(thread.bookmarkListPage) { thread.bookmarkListPage = Int32(pageNumber) }
                }
                else {
                    if pageNumber != Int(thread.threadListPage) { thread.threadListPage = Int32(pageNumber) }
                }
            }

            if forum != thread.forum { thread.forum = forum }

            if let ratingImageBasename = raw.ratingImageBasename {
                if ratingImageBasename != thread.ratingImageBasename { thread.ratingImageBasename = ratingImageBasename }
            }
          
            if let icon = raw.icon {
                let tag = iconHelper.upsert(icon)
                if tag != thread.threadTag { thread.threadTag = tag }
            }

            if let secondaryIcon = raw.secondaryIcon {
                let secondaryTag = iconHelper.upsert(secondaryIcon)
                if secondaryTag != thread.secondaryThreadTag { thread.secondaryThreadTag = secondaryTag }
            }

            if raw.isSticky {
                if stickyIndex != Int(thread.stickyIndex) { thread.stickyIndex = Int32(stickyIndex) }
                stickyIndex += 1
            }

            threads.append(thread)
        }

        return threads
    }
}

internal extension ThreadListScrapeResult.Thread {
    func update(_ thread: AwfulThread) {
        let isBookmarked: Bool = {
            switch bookmark {
            case .orange, .red, .yellow, .teal, .green, .purple:
                return true
            case .none:
                return false
            }
        }()
        if isBookmarked != thread.bookmarked { thread.bookmarked = isBookmarked }

        if id.rawValue != thread.threadID { thread.threadID = id.rawValue }
        if isClosed != thread.closed { thread.closed = isClosed }
        if isSticky != thread.sticky { thread.sticky = isSticky }
        
        if let ratingImageBasename = ratingImageBasename, ratingImageBasename != thread.ratingImageBasename {
            thread.ratingImageBasename = ratingImageBasename
        }
        
        if !lastPostAuthorUsername.isEmpty, lastPostAuthorUsername != thread.lastPostAuthorName { thread.lastPostAuthorName = lastPostAuthorUsername }
        if let lastPostDate = lastPostDate, lastPostDate != thread.lastPostDate as Date? { thread.lastPostDate = lastPostDate as NSDate }
        if let ratingAverage = ratingAverage, ratingAverage != Float(thread.rating) { thread.rating = Float32(ratingAverage) }
        if let ratingCount = ratingCount, ratingCount != Int(thread.numberOfVotes) { thread.numberOfVotes = Int32(ratingCount) }

        let starCategory: StarCategory = {
            switch bookmark {
            case .orange: return .orange
            case .red: return .red
            case .yellow: return .yellow
            case .teal: return .teal
            case .green: return .green
            case .purple: return .purple
            case .none: return .none
            }
        }()
        if starCategory != thread.starCategory { thread.starCategory = starCategory }

        if let replyCount = replyCount {
            if replyCount != Int(thread.totalReplies) { thread.totalReplies = Int32(replyCount) }

            let seenPosts: Int = {
                if let unreadPostCount = unreadPostCount {
                    return replyCount + 1 - unreadPostCount
                }
                else if isUnread {
                    return 0
                }
                else {
                    return replyCount + 1
                }
            }()

            if seenPosts != Int(thread.seenPosts) { thread.seenPosts = Int32(seenPosts) }
        }
        
        // Merely coming across a thread in a list means it must have at least one page. But if it has no replies, we won't have set the number of pages appropriately, so we need to handle that here.
        if thread.numberOfPages == 0 {
            thread.numberOfPages = 1
        }

        if !title.isEmpty, title != thread.title { thread.title = title }
    }
}
