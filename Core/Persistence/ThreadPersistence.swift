//
//  ThreadPersistence.swift
//  Awful
//
//  Created by Nolan Waite on 2017-06-17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import CoreData

internal extension ThreadListScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [AwfulThread] {
        let (group: _, forums: forums) = try breadcrumbs?.upsert(into: context) ?? (nil, [])
        let forum = forums.last

        let icons = self.threads.flatMap { $0.icon }
            + self.threads.flatMap { $0.secondaryIcon }
            + self.filterableIcons
        let iconHelper = IconHelper(context: context, icons: icons)
        try iconHelper.performFetch()

        for icon in filterableIcons {
            _ = iconHelper.upsert(icon)
        }

        var users: [UserID: User] = [:]
        do {
            let request = NSFetchRequest<User>(entityName: User.entityName())
            let userIDs = self.threads.flatMap { $0.author?.rawValue }
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(User.userID), userIDs)
            request.returnsObjectsAsFaults = false

            for user in try context.fetch(request) {
                guard let id = UserID(rawValue: user.userID) else { continue }
                users[id] = user
            }
        }

        var existingThreads: [ThreadID: AwfulThread] = [:]
        do {
            let request = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
            let threadIDs = self.threads.map { $0.id.rawValue }
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(AwfulThread.threadID), threadIDs)
            request.returnsObjectsAsFaults = false

            for thread in try context.fetch(request) {
                guard let id = ThreadID(rawValue: thread.threadID) else { continue }
                existingThreads[id] = thread
            }
        }

        var threads: [AwfulThread] = []
        var stickyIndex = -self.threads.count
        for raw in self.threads {
            let thread = existingThreads[raw.id]
                ?? AwfulThread.insertIntoManagedObjectContext(context: context)

            raw.update(thread)

            if let authorID = raw.author {
                let author = users[authorID] ?? {
                    let author = User.insertIntoManagedObjectContext(context: context)
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

private class IconHelper {
    private let context: NSManagedObjectContext
    private let icons: [ThreadListScrapeResult.Icon]
    private var byID: [String: ThreadTag] = [:]
    private var byImageName: [String: ThreadTag] = [:]

    init(context: NSManagedObjectContext, icons: [ThreadListScrapeResult.Icon]) {
        self.context = context
        self.icons = icons
    }

    func performFetch() throws {
        let request = NSFetchRequest<ThreadTag>(entityName: ThreadTag.entityName())
        let threadTagIDs = icons
            .map { $0.id }
            .filter { !$0.isEmpty }
        let imageNames = icons
            .flatMap { $0.url }
            .map(ThreadTag.imageName)
            .filter { !$0.isEmpty }
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "%K IN %@", #keyPath(ThreadTag.threadTagID), threadTagIDs),
            NSPredicate(format: "%K IN %@", #keyPath(ThreadTag.imageName), imageNames)])
        request.returnsObjectsAsFaults = false

        for tag in try context.fetch(request) {
            if let id = tag.threadTagID {
                byID[id] = tag
            }

            if let imageName = tag.imageName {
                byImageName[imageName] = tag
            }
        }
    }

    func upsert(_ icon: ThreadListScrapeResult.Icon) -> ThreadTag {
        let fromID = icon.id.isEmpty ? nil : byID[icon.id]
        let imageName = icon.url.map(ThreadTag.imageName)
        let fromImageName = imageName.flatMap { byImageName[$0] }
        let tag = fromID ?? fromImageName ?? ThreadTag.insertIntoManagedObjectContext(context: context)
        icon.update(tag)

        if fromID == nil, let id = tag.threadTagID { byID[id] = tag }
        if fromImageName == nil, let imageName = imageName { byImageName[imageName] = tag }

        return tag
    }
}

internal extension ThreadListScrapeResult.Icon {
    func update(_ tag: ThreadTag) {
        if !id.isEmpty, id != tag.threadTagID { tag.threadTagID = id }
        if let imageName = url.map(ThreadTag.imageName), imageName != tag.imageName { tag.imageName = imageName }
    }
}

internal extension ThreadListScrapeResult.Thread {
    func update(_ thread: AwfulThread) {
        let isBookmarked: Bool = {
            switch bookmark {
            case .orange, .red, .yellow: return true
            case .none: return false
            }
        }()
        if isBookmarked != thread.bookmarked { thread.bookmarked = isBookmarked }

        if id.rawValue != thread.threadID { thread.threadID = id.rawValue }
        if isClosed != thread.closed { thread.closed = isClosed }
        if isSticky != thread.sticky { thread.sticky = isSticky }
        if !lastPostAuthorUsername.isEmpty, lastPostAuthorUsername != thread.lastPostAuthorName { thread.lastPostAuthorName = lastPostAuthorUsername }
        if let lastPostDate = lastPostDate, lastPostDate != thread.lastPostDate as Date? { thread.lastPostDate = lastPostDate as NSDate }
        if let ratingAverage = ratingAverage, ratingAverage != Float(thread.rating) { thread.rating = Float32(ratingAverage) }
        if let ratingCount = ratingCount, ratingCount != Int(thread.numberOfVotes) { thread.numberOfVotes = Int32(ratingCount) }

        let starCategory: StarCategory = {
            switch bookmark {
            case .orange: return .Orange
            case .red: return .Red
            case .yellow: return .Yellow
            case .none: return .None
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

        if !title.isEmpty, title != thread.title { thread.title = title }
    }
}
