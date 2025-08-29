//  ForumsClient+Sendable.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import Foundation
import CoreData

// MARK: - Thread Operations with Sendable Types

extension ForumsClient {
    
    /// Sets a thread's bookmark status using thread ID directly (Sendable-safe)
    public func setThread(
        threadID: String,
        isBookmarked: Bool
    ) async throws {
        _ = try await fetch(method: .post, urlString: "bookmarkthreads.php", parameters: [
            "json": "1",
            "action": isBookmarked ? "add" : "remove",
            "threadid": threadID,
        ])
        
        // Update Core Data on main context if available
        if let mainContext = managedObjectContext {
            await mainContext.perform {
                let fetch = NSFetchRequest<AwfulThread>(entityName: "Thread")
                fetch.predicate = NSPredicate(format: "threadID == %@", threadID)
                if let thread = try? mainContext.fetch(fetch).first {
                    thread.bookmarked = isBookmarked
                    if isBookmarked, thread.bookmarkListPage <= 0 {
                        thread.bookmarkListPage = 1
                    }
                    try? mainContext.save()
                }
            }
        }
    }
    
    /// Sets a thread's bookmark color using thread ID directly (Sendable-safe)
    public func setBookmarkColor(
        threadID: String,
        category: StarCategory
    ) async throws {
        _ = try await fetch(method: .post, urlString: "bookmarkthreads.php", parameters: [
            "threadid": threadID,
            "action": "add",
            "category_id": "\(category.rawValue)",
            "json": "1",
        ])
        
        // Update Core Data on main context if available
        if let mainContext = managedObjectContext {
            await mainContext.perform {
                let fetch = NSFetchRequest<AwfulThread>(entityName: "Thread")
                fetch.predicate = NSPredicate(format: "threadID == %@", threadID)
                if let thread = try? mainContext.fetch(fetch).first {
                    if thread.bookmarkListPage <= 0 {
                        thread.bookmarkListPage = 1
                    }
                    if thread.starCategory != category {
                        thread.starCategory = category
                    }
                    try? mainContext.save()
                }
            }
        }
    }
    
    /// Marks a thread as unread using thread ID directly (Sendable-safe)
    public func markUnread(
        threadID: String
    ) async throws {
        _ = try await fetch(method: .post, urlString: "showthread.php", parameters: [
            "threadid": threadID,
            "action": "resetseen",
            "json": "1",
        ])
    }
    
    /// Rates a thread using thread ID directly (Sendable-safe)
    public func rate(
        threadID: String,
        rating: Int
    ) async throws {
        _ = try await fetch(method: .post, urlString: "threadrate.php", parameters: [
            "vote": "\(rating.clamped(to: 1...5))",
            "threadid": threadID,
        ])
    }
    
    /// Lists posts in a thread using ThreadInfo (Sendable-safe) - returns PostsPageResult
    public func listPosts(
        threadInfo: ThreadInfo,
        authorUserID: String? = nil,
        page: ThreadPage,
        updateLastReadPost: Bool
    ) async throws -> PostsPageResult {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }
        
        var parameters: Dictionary<String, Any> = [
            "threadid": threadInfo.threadID,
            "perpage": "40",
        ]
        
        switch page {
        case .nextUnread:
            parameters["goto"] = "newpost"
        case .last:
            parameters["goto"] = "lastpost"
        case .specific(let pageNumber):
            parameters["pagenumber"] = "\(pageNumber)"
        }
        
        if !updateLastReadPost {
            parameters["noseen"] = "1"
        }
        
        if let authorUserID = authorUserID {
            parameters["userid"] = authorUserID
        }
        
        func redirect(
            response: HTTPURLResponse,
            newRequest: URLRequest
        ) async -> URLRequest? {
            var components = newRequest.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
            let queryItems = (components?.queryItems ?? [])
                .filter { $0.name != "perpage" }
            components?.queryItems = queryItems
                + [URLQueryItem(name: "perpage", value: "40")]
            
            var request = newRequest
            request.url = components?.url
            return request
        }
        
        let (data, response) = try await fetch(method: .get, urlString: "showthread.php", parameters: parameters, willRedirect: redirect)
        let (document, url) = try parseHTML(data: data, response: response)
        let result = try PostsPageScrapeResult(document, url: url)
        
        try Task.checkCancellation()
        
        let (backgroundPosts, postInfos) = try await backgroundContext.perform {
            let posts = try result.upsert(into: backgroundContext)
            try backgroundContext.save()
            let postInfos = posts.map { $0.postInfo }
            return (posts, postInfos)
        }
        
        let postObjectIDs = backgroundPosts.map { $0.objectID }
        
        return PostsPageResult(
            postInfos: postInfos,
            postObjectIDs: postObjectIDs,
            firstUnreadPost: result.jumpToPostIndex.map { $0 + 1 },
            advertisementHTML: result.advertisement,
            pageNumber: 1, // TODO: Extract from result if available
            totalPages: 1  // TODO: Extract from result if available
        )
    }
    
    /// Marks thread as seen up to a specific post using PostInfo (Sendable-safe)
    public func markThreadAsSeenUpTo(
        postInfo: PostInfo
    ) async throws {
        guard let threadID = postInfo.threadID else {
            assertionFailure("post needs a thread ID")
            let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            throw error
        }
        _ = try await fetch(method: .post, urlString: "showthread.php", parameters: [
            "action": "setseen",
            "threadid": threadID,
            "index": "\(postInfo.postIndex)",
        ])
    }
}

// MARK: - Post Operations with Sendable Types

extension ForumsClient {
    
    /// Reads an ignored post using PostInfo (Sendable-safe)
    public func readIgnoredPost(
        postID: String
    ) async throws {
        guard let backgroundContext = backgroundManagedObjectContext
        else { throw Error.missingManagedObjectContext }
        
        let (data, response) = try await fetch(method: .get, urlString: "showthread.php", parameters: [
            "action": "showpost",
            "postid": postID,
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        let result = try ShowPostScrapeResult(document, url: url)
        try await backgroundContext.perform {
            _ = try result.upsert(into: backgroundContext)
            try backgroundContext.save()
        }
    }
    
    /// Reports a post using PostInfo (Sendable-safe)
    public func report(
        postID: String,
        nws: Bool,
        reason: String
    ) async throws {
        var parameters: [String: Any] = [
            "action": "submit",
            "postid": postID,
            "comments": String(reason.prefix(960)),
        ]
        if nws {
            parameters["nws"] = "yes"
        }
        _ = try await fetch(method: .post, urlString: "modalert.php", parameters: parameters)
    }
    
    /// Finds BBcode contents of a post using post ID (Sendable-safe)
    public func findBBcodeContents(
        postID: String
    ) async throws -> String {
        let (data, response) = try await fetch(method: .get, urlString: "editpost.php", parameters: [
            "action": "editpost",
            "postid": postID,
        ])
        let document = try parseHTML(data: data, response: response)
        return try findMessageText(in: document)
    }
    
    /// Quotes BBcode contents of a post using post ID (Sendable-safe)
    public func quoteBBcodeContents(
        postID: String
    ) async throws -> String {
        let (data, response) = try await fetch(method: .get, urlString: "newreply.php", parameters: [
            "action": "newreply",
            "postid": postID,
        ])
        let parsed = try parseHTML(data: data, response: response)
        return try findMessageText(in: parsed)
    }
}

// MARK: - User Operations with Sendable Types

extension ForumsClient {
    
    /// Profiles a user using UserInfo (Sendable-safe)
    public func profileUser(
        userInfo: UserInfo
    ) async throws -> Profile {
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }
        
        var parameters = ["action": "getinfo", "userid": userInfo.userID]
        if let username = userInfo.username {
            parameters["username"] = username
        }
        
        let backgroundProfile = try await profile(parameters: parameters)
        return try await mainContext.perform {
            guard let profile = mainContext.object(with: backgroundProfile.objectID) as? Profile else {
                throw AwfulCoreError.parseError(description: "Could not save profile")
            }
            return profile
        }
    }
    
    /// Lists punishments for a user using UserInfo (Sendable-safe)
    public func listPunishments(
        userInfo: UserInfo?,
        page: Int
    ) async throws -> [LepersColonyScrapeResult.Punishment] {
        guard let userInfo = userInfo else {
            return try await lepersColony(parameters: ["pagenumber": "\(page)"])
        }
        
        var userID = userInfo.userID
        if userID.isEmpty, let username = userInfo.username {
            // Need to fetch user ID first
            let profile = try await profileUser(userInfo: UserInfo(userID: "", username: username))
            userID = await profile.managedObjectContext!.perform {
                profile.user.userID
            }
        }
        
        return try await lepersColony(parameters: [
            "pagenumber": "\(page)",
            "userid": userID,
        ])
    }
}

// MARK: - Private Message Operations with Sendable Types

extension ForumsClient {
    
    /// Deletes a private message using message ID (Sendable-safe)
    public func deletePrivateMessage(
        messageID: String
    ) async throws {
        let (data, response) = try await fetch(method: .post, urlString: "private.php", parameters: [
            "action": "dodelete",
            "privatemessageid": messageID,
            "delete": "yes",
        ])
        let (document, _) = try parseHTML(data: data, response: response)
        try checkServerErrors(document)
    }
    
    /// Quotes BBcode contents of a message using message ID (Sendable-safe)
    public func quoteBBcodeContents(
        messageID: String
    ) async throws -> String {
        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: [
            "action": "newmessage",
            "privatemessageid": messageID,
        ])
        let parsed = try parseHTML(data: data, response: response)
        return try findMessageText(in: parsed)
    }
}

// MARK: - Forum Operations with Sendable Types

extension ForumsClient {
    
    /// Gets a flag for a thread in a forum using forum ID (Sendable-safe)
    public func flagForThread(
        forumID: String
    ) async throws -> Flag {
        let (data, _) = try await fetch(method: .get, urlString: "flag.php", parameters: [
            "forumid": forumID,
        ])
        return try JSONDecoder().decode(Flag.self, from: data)
    }
    
    /// Lists available post icons in a forum using forum ID (Sendable-safe)
    public func listAvailablePostIcons(
        forumID: String
    ) async throws -> (primary: [ThreadTag], secondary: [ThreadTag]) {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }
        
        let (data, response) = try await fetch(method: .get, urlString: "newthread.php", parameters: [
            "action": "newthread",
            "forumid": forumID,
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        let result = try PostIconListScrapeResult(document, url: url)
        let backgroundTags = try await backgroundContext.perform {
            let managed = try result.upsert(into: backgroundContext)
            try backgroundContext.save()
            return (primary: managed.primary, secondary: managed.secondary)
        }
        return await mainContext.perform {
            (
                primary: backgroundTags.primary.compactMap { mainContext.object(with: $0.objectID) as? ThreadTag },
                secondary: backgroundTags.secondary.compactMap { mainContext.object(with: $0.objectID) as? ThreadTag }
            )
        }
    }
}

// MARK: - Thread Reply Operations with Sendable Types

extension ForumsClient {
    
    /// Replies to a thread using thread ID (Sendable-safe)
    public func reply(
        threadID: String,
        bbcode: String
    ) async throws -> ReplyLocation {
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }
        
        let formParams: [KeyValuePairs<String, Any>.Element]
        do {
            let (data, response) = try await fetch(method: .get, urlString: "newreply.php", parameters: [
                "action": "newreply",
                "threadid": threadID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            guard let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']") else {
                throw AwfulCoreError.parseError(description: "Could not reply; failed to find the form.")
            }
            let parsedForm = try Form(htmlForm, url: url)
            let form = SubmittableForm(parsedForm)
            try form.enter(text: bbcode, for: "message")
            let submission = form.submit(button: parsedForm.submitButton(named: "submit"))
            formParams = prepareFormEntries(submission)
        }
        
        let postID: String?
        do {
            let (data, response) = try await fetch(method: .post, urlString: "newreply.php", parameters: formParams)
            let (document, _) = try parseHTML(data: data, response: response)
            let link = document.firstNode(matchingSelector: "a[href *= 'goto=post']")
            ?? document.firstNode(matchingSelector: "a[href *= 'goto=lastpost']")
            let queryItems = link
                .flatMap { $0["href"] }
                .flatMap { URLComponents(string: $0) }
                .flatMap { $0.queryItems }
            postID = if let goto = queryItems?.first(where: { $0.name == "goto" }), goto.value == "post" {
                queryItems?.first(where: { $0.name == "postid" })?.value
            } else {
                nil
            }
        }
        return await mainContext.perform {
            if let postID {
                .post(Post.objectForKey(objectKey: PostKey(postID: postID), in: mainContext))
            } else {
                .lastPostInThread
            }
        }
    }
    
    /// Previews a reply to a thread using thread ID (Sendable-safe)
    public func previewReply(
        threadID: String,
        bbcode: String
    ) async throws -> String {
        let params: [KeyValuePairs<String, Any>.Element]
        do {
            let (data, response) = try await fetch(method: .get, urlString: "newreply.php", parameters: [
                "action": "newreply",
                "threadid": threadID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            let htmlForm = try document.requiredNode(matchingSelector: "form[name = 'vbform']")
            let scrapedForm = try Form(htmlForm, url: url)
            let form = SubmittableForm(scrapedForm)
            try form.enter(text: bbcode, for: "message")
            let submission = form.submit(button: scrapedForm.submitButton(named: "preview"))
            params = prepareFormEntries(submission)
        }
        
        try Task.checkCancellation()
        
        do {
            let (data, response) = try await fetch(method: .post, urlString: "newreply.php", parameters: params)
            let (document, _) = try parseHTML(data: data, response: response)
            guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
                throw AwfulCoreError.parseError(description: "Could not find previewed post")
            }
            workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
            return postbody.innerHTML
        }
    }
}
