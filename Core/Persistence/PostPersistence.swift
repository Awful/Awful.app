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

        if !isIgnored, body != post.innerHTML { post.innerHTML = body }
        if id.rawValue != post.postID { post.postID = id.rawValue }
        if isEditable != post.editable { post.editable = isEditable }
        if isIgnored != post.ignored { post.ignored = isIgnored }
        if let postDate = postDate, postDate != post.postDate as Date? { post.postDate = postDate as NSDate }
    }
}

internal extension PostsPageScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [Post] {
        let forum: Forum? = try {
            if
                let breadcrumbs = breadcrumbs,
                let forums = try? breadcrumbs.upsert(into: context).forums,
                let last = forums.last,
                last.forumID == forumID?.rawValue
            {
                return last
            }
            else if let forumID = forumID {
                let request = NSFetchRequest<Forum>(entityName: Forum.entityName())
                request.predicate = NSPredicate(format: "%K = %@", #keyPath(Forum.forumID), forumID.rawValue)
                request.returnsObjectsAsFaults = false

                if let forum = try context.fetch(request).first {
                    return forum
                }
                else {
                    let forum = Forum.insertIntoManagedObjectContext(context: context)
                    forum.forumID = forumID.rawValue
                    return forum
                }
            }
            else {
                return nil
            }
        }()

        let users = try upsertUsers(into: context)

        let thread = try threadID.map { id -> AwfulThread in
            let request = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
            request.predicate = NSPredicate(format: "%K = %@", #keyPath(AwfulThread.threadID), id.rawValue)
            request.returnsObjectsAsFaults = false

            let thread = try context.fetch(request).first
                ?? AwfulThread.insertIntoManagedObjectContext(context: context)

            if let forum = forum, thread.forum != forum { thread.forum = forum }
            if id.rawValue != thread.threadID { thread.threadID = id.rawValue }
            if let isBookmarked = threadIsBookmarked, isBookmarked != thread.bookmarked { thread.bookmarked = isBookmarked }
            if threadIsClosed != thread.closed { thread.closed = threadIsClosed }
            if !threadTitle.isEmpty, threadTitle != thread.title { thread.title = threadTitle }

            if let pageCount = pageCount {
                if isSingleUserFilterEnabled {
                    if let firstAuthor = self.posts.first?.author, let user = users[firstAuthor.userID] {
                        thread.setFilteredNumberOfPages(numberOfPages: Int32(pageCount), forAuthor: user)
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

        var existingPosts: [PostID: Post] = [:]
        let request = NSFetchRequest<Post>(entityName: Post.entityName())
        let postIDs = self.posts.map { $0.id.rawValue }
        request.predicate = NSPredicate(format: "%K in %@", #keyPath(Post.postID), postIDs)
        request.returnsObjectsAsFaults = false
        for post in try context.fetch(request) {
            guard let id = PostID(rawValue: post.postID) else { continue }
            existingPosts[id] = post
        }

        let posts = self.posts.map { raw -> Post in
            let post = existingPosts[raw.id] ?? Post.insertIntoManagedObjectContext(context: context)

            if let thread = thread, thread != post.thread { post.thread = thread }
            if let user = users[raw.author.userID], user != post.author { post.author = user }

            raw.update(post)

            if let indexInThread = raw.indexInThread {
                if isSingleUserFilterEnabled {
                    if indexInThread != Int(post.filteredThreadIndex) { post.filteredThreadIndex = Int32(indexInThread) }
                }
                else {
                    if indexInThread != Int(post.threadIndex) { post.threadIndex = Int32(indexInThread) }
                }
            }

            return post
        }

        if
            !isSingleUserFilterEnabled,
            let thread = thread,
            let firstUnseen = self.posts.first(where: { !$0.hasBeenSeen }),
            let indexInThread = firstUnseen.indexInThread
        {
            let seenPostCount = indexInThread - 1
            if seenPostCount != Int(thread.seenPosts) { thread.seenPosts = Int32(seenPostCount) }
        }

        return posts
    }

    private func upsertUsers(into context: NSManagedObjectContext) throws -> [UserID: User] {
        var users: [UserID: User] = [:]

        let authors = posts.map { $0.author }
        let userIDs = authors.map { $0.userID }
        let request = NSFetchRequest<User>(entityName: User.entityName())
        request.predicate = NSPredicate(format: "%K in %@", #keyPath(User.userID), userIDs)
        request.returnsObjectsAsFaults = false

        for user in try context.fetch(request) {
            guard let id = UserID(rawValue: user.userID) else { continue }
            users[id] = user
        }

        for author in authors {
            let user = users[author.userID] ?? User.insertIntoManagedObjectContext(context: context)
            author.update(user)
            users[author.userID] = user
        }

        return users
    }
}
