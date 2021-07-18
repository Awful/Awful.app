//  PostPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension PostScrapeResult {
    func update(_ post: Post) {
        if let user = post.author {
            author.update(user)

            if authorCanReceivePrivateMessages != user.canReceivePrivateMessages { user.canReceivePrivateMessages = authorCanReceivePrivateMessages }
        }

        if !body.isEmpty, body != post.innerHTML { post.innerHTML = body }
        if id.rawValue != post.postID { post.postID = id.rawValue }
        if isEditable != post.editable { post.editable = isEditable }
        if isIgnored != post.ignored { post.ignored = isIgnored }
        if let postDate = postDate, postDate != post.postDate { post.postDate = postDate }
    }
}

internal extension PostsPageScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [Post] {
        let forum: Forum? = {
            if
                let breadcrumbs = breadcrumbs,
                let forums = try? breadcrumbs.upsert(into: context).forums,
                let last = forums.last,
                last.forumID == forumID?.rawValue
            {
                return last
            }
            else if let forumID = forumID {
                return Forum.findOrCreate(
                    in: context,
                    matching: .init("\(\Forum.forumID) = \(forumID.rawValue)"),
                    configure: { $0.forumID = forumID.rawValue })
            }
            else {
                return nil
            }
        }()

        let users = try upsertUsers(into: context)

        let thread = threadID.map { id -> AwfulThread in
            let thread = AwfulThread.findOrCreate(
                in: context,
                matching: .init("\(\AwfulThread.threadID) = \(id.rawValue)"),
                configure: { $0.threadID = id.rawValue })

            if let forum = forum, thread.forum != forum { thread.forum = forum }
            if id.rawValue != thread.threadID { thread.threadID = id.rawValue }
            if let isBookmarked = threadIsBookmarked, isBookmarked != thread.bookmarked { thread.bookmarked = isBookmarked }
            if threadIsClosed != thread.closed { thread.closed = threadIsClosed }
            if !threadTitle.isEmpty, threadTitle != thread.title { thread.title = threadTitle }

            if let pageCount = pageCount {
                if isSingleUserFilterEnabled {
                    if let firstAuthor = self.posts.first?.author, let user = users[firstAuthor.userID] {
                        thread.setFilteredNumberOfPages(Int32(pageCount), forAuthor: user)
                    }
                }
                else {
                    if pageCount != Int(thread.numberOfPages) { thread.numberOfPages = Int32(pageCount) }
                }
            }

            if
                !isSingleUserFilterEnabled,
                let pageCount = pageCount,
                let pageNumber = pageNumber,
                pageCount == pageNumber,
                let lastPost = self.posts.last
            {
                if !lastPost.author.username.isEmpty, lastPost.author.username != thread.lastPostAuthorName { thread.lastPostAuthorName = lastPost.author.username }
                if let postDate = lastPost.postDate, postDate != thread.lastPostDate as Date? { thread.lastPostDate = postDate as NSDate }
            }

            if
                let op = self.posts.first(where: { $0.authorIsOriginalPoster })?.author,
                let user = users[op.userID],
                user != thread.author
            {
                thread.author = user
            }

            return thread
        }

        let existingPosts = Dictionary(
            Post.fetch(in: context) { request in
                let postIDs = self.posts.map { $0.id.rawValue }
                request.predicate = .init("\(\Post.postID) in \(postIDs)")
                request.returnsObjectsAsFaults = false
            }.map { (PostID(rawValue: $0.postID)!, $0) },
            uniquingKeysWith: { $1 }
        )

        let posts = self.posts.map { raw -> Post in
            let post = existingPosts[raw.id] ?? Post.insert(into: context)

            if let thread = thread, thread != post.thread { post.thread = thread }
            if let user = users[raw.author.userID], user != post.author { post.author = user }

            raw.update(post)

            return post
        }

        // Ignored posts don't inform us of their index within the thread, so we need to try our best to derive correct indices.
        let calculatedIndices: [Int]
        if
            let hasIndexInThread = self.posts.firstIndex(where: { $0.indexInThread != nil }),
            let indexInThread = self.posts[hasIndexInThread].indexInThread
        {
            calculatedIndices = posts.indices.map { indexInThread + $0 - hasIndexInThread }
        }
        else if let pageNumber = pageNumber, let postsPerPage = postsPerPage {
            let start = (pageNumber - 1) * postsPerPage + 1
            calculatedIndices = posts.indices.map { $0 + start }
        }
        else {
            calculatedIndices = []
        }

        for (calculatedIndex, post) in zip(calculatedIndices, posts) {
            if isSingleUserFilterEnabled {
                if calculatedIndex != Int(post.filteredThreadIndex) { post.filteredThreadIndex = Int32(calculatedIndex) }
            }
            else {
                if calculatedIndex != Int(post.threadIndex) { post.threadIndex = Int32(calculatedIndex) }
            }
        }

        if
            !isSingleUserFilterEnabled,
            let thread = thread,
            let firstUnseen = posts.first(where: { !$0.beenSeen }),
            firstUnseen.threadIndex > 0
        {
            let seenPostCount = firstUnseen.threadIndex - 1
            if seenPostCount != thread.seenPosts { thread.seenPosts = seenPostCount }
        }

        return posts
    }

    private func upsertUsers(
        into context: NSManagedObjectContext
    ) throws -> [UserID: User] {
        let authors = posts.map { $0.author }

        var users = Dictionary(
            grouping: User.fetch(in: context) { request in
                let userIDs = Set(posts.map { $0.author.userID.rawValue })
                request.predicate = .init("\(\User.userID) IN \(userIDs)")
                request.returnsObjectsAsFaults = false
            },
            by: { UserID(rawValue: $0.userID)! }
        ).mapValues(merge)

        for author in authors {
            let user = users[author.userID] ?? User.insert(into: context)
            author.update(user)
            users[author.userID] = user
        }

        return users
    }
}

internal extension ShowPostScrapeResult {
    func upsert(
        into context: NSManagedObjectContext
    ) throws -> Post {
        let post = Post.findOrCreate(
            in: context,
            matching: .init("\(\Post.postID) = \(self.post.id.rawValue)"),
            configure: { $0.postID = self.post.id.rawValue} )

        let user = try author.upsert(into: context)
        if user != post.author { post.author = user }

        self.post.update(post)

        let thread = threadID.map { id -> AwfulThread in
            let thread = AwfulThread.findOrCreate(
                in: context,
                matching: .init("\(\AwfulThread.threadID) = \(id.rawValue)"),
                configure: { $0.threadID = id.rawValue })

            return thread
        }

        if let thread = thread, thread != post.thread { post.thread = thread }

        return post
    }
}
