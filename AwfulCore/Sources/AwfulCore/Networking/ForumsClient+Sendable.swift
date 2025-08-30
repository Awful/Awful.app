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
        guard let backgroundContext = backgroundManagedObjectContext
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
        
        // Extract data needed before entering the closure
        let jumpToPostIndex = result.jumpToPostIndex
        let advertisement = result.advertisement
        
        let (backgroundPosts, postInfos) = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable types
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PostsPageScrapeResult(innerDocument, url: innerUrl)
            let posts = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            let postInfos = posts.map { $0.postInfo }
            return (posts, postInfos)
        }
        
        let postObjectIDs = backgroundPosts.map { $0.objectID }
        
        return PostsPageResult(
            postInfos: postInfos,
            postObjectIDs: postObjectIDs,
            firstUnreadPost: jumpToPostIndex.map { $0 + 1 },
            advertisementHTML: advertisement,
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
        // Parse the result outside the closure to avoid capturing non-Sendable type
        _ = try ShowPostScrapeResult(document, url: url)
        
        // Reparse inside the closure
        try await backgroundContext.perform {
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try ShowPostScrapeResult(innerDocument, url: innerUrl)
            _ = try innerResult.upsert(into: backgroundContext)
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
        
        let backgroundProfileObjectID = try await profile(parameters: parameters).objectID
        return try await mainContext.perform {
            guard let profile = mainContext.object(with: backgroundProfileObjectID) as? Profile else {
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
            let profileObjectID = profile.objectID
            let context = profile.managedObjectContext!
            userID = await context.perform {
                let profileObj = context.object(with: profileObjectID) as! Profile
                return profileObj.user.userID
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
        // Parse result outside closure to validate, then reparse inside
        _ = try PostIconListScrapeResult(document, url: url)
        
        let backgroundTags = try await backgroundContext.perform {
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PostIconListScrapeResult(innerDocument, url: innerUrl)
            let managed = try innerResult.upsert(into: backgroundContext)
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

// MARK: - Thread Listing Operations with Sendable Types

extension ForumsClient {
    
    /// Lists threads in a forum using forum ID (Sendable-safe)
    public func listThreads(
        forumID: String,
        threadTagID: String? = nil,
        page: Int
    ) async throws -> [AwfulThread] {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }
        
        var parameters: Dictionary<String, Any> = [
            "forumid": forumID,
            "perpage": "40",
            "pagenumber": "\(page)"
        ]
        if let threadTagID = threadTagID, !threadTagID.isEmpty {
            parameters["posticon"] = threadTagID
        }
        
        let (data, response) = try await fetch(method: .get, urlString: "forumdisplay.php", parameters: parameters)
        let (document, url) = try parseHTML(data: data, response: response)
        // Parse result outside closure to validate, then reparse inside
        let canPostNewThread = try ThreadListScrapeResult(document, url: url).canPostNewThread
        
        let backgroundThreadObjectIDs = try await backgroundContext.perform {
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try ThreadListScrapeResult(innerDocument, url: innerUrl)
            let threads = try innerResult.upsert(into: backgroundContext)
            _ = try innerResult.upsertAnnouncements(into: backgroundContext)
            
            // Update forum's canPost status
            let forumFetch = NSFetchRequest<Forum>(entityName: "Forum")
            forumFetch.predicate = NSPredicate(format: "forumID == %@", forumID)
            if let forum = try? backgroundContext.fetch(forumFetch).first {
                forum.canPost = canPostNewThread
                
                if page == 1,
                   var threadsToForget = threads.first?.forum?.threads {
                    threadsToForget.subtract(threads)
                    threadsToForget.forEach { $0.threadListPage = 0 }
                }
            }
            
            try backgroundContext.save()
            return threads.map { $0.objectID }
        }
        
        return await mainContext.perform {
            backgroundThreadObjectIDs.compactMap { mainContext.object(with: $0) as? AwfulThread }
        }
    }
}

// MARK: - Post Editing Operations with Sendable Types

extension ForumsClient {
    
    /// Edits a post using post ID (Sendable-safe)
    public func edit(
        postID: String,
        bbcode: String
    ) async throws {
        let formParams: [KeyValuePairs<String, Any>.Element]
        do {
            let (data, response) = try await fetch(method: .get, urlString: "editpost.php", parameters: [
                "action": "editpost",
                "postid": postID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            guard let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']") else {
                throw AwfulCoreError.parseError(description: "Could not edit post; failed to find the form.")
            }
            let parsedForm = try Form(htmlForm, url: url)
            let form = SubmittableForm(parsedForm)
            try form.enter(text: bbcode, for: "message")
            let submission = form.submit(button: parsedForm.submitButton(named: "submit"))
            formParams = prepareFormEntries(submission)
        }
        
        _ = try await fetch(method: .post, urlString: "editpost.php", parameters: formParams)
    }
    
    /// Previews editing a post using post ID (Sendable-safe)
    public func previewEdit(
        postID: String,
        bbcode: String
    ) async throws -> String {
        let params: [KeyValuePairs<String, Any>.Element]
        do {
            let (data, response) = try await fetch(method: .get, urlString: "editpost.php", parameters: [
                "action": "editpost",
                "postid": postID,
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
            let (data, response) = try await fetch(method: .post, urlString: "editpost.php", parameters: params)
            let (document, _) = try parseHTML(data: data, response: response)
            guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
                throw AwfulCoreError.parseError(description: "Could not find previewed post")
            }
            workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
            return postbody.innerHTML
        }
    }
}

// MARK: - Thread Creation Operations with Sendable Types

extension ForumsClient {
    
    /// Posts a new thread to a forum using forum ID (Sendable-safe)
    public func postThread(
        forumID: String,
        subject: String,
        threadTagID: String? = nil,
        secondaryThreadTagID: String? = nil,
        bbcode: String
    ) async throws -> AwfulThread {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }
        
        // Get the form data
        let formData: PostNewThreadFormData
        do {
            let (data, response) = try await fetch(method: .get, urlString: "newthread.php", parameters: [
                "action": "newthread",
                "forumid": forumID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            let htmlForm = try document.requiredNode(matchingSelector: "form[name = 'vbform']")
            formData = try PostNewThreadFormData(htmlForm, url: url)
        }
        
        // Prepare form submission
        let form = SubmittableForm(formData.form)
        try form.enter(text: subject, for: "subject")
        try form.enter(text: bbcode, for: "message")
        
        if let threadTagID = threadTagID {
            if formData.threadTagInputs.allSatisfy({ $0["value"] != threadTagID }) {
                throw AwfulCoreError.parseError(description: "Could not find thread tag")
            }
            try form.select(value: threadTagID, for: formData.threadTagName)
        }
        
        if let secondaryThreadTagID = secondaryThreadTagID,
           let secondaryName = formData.secondaryThreadTagName {
            if formData.secondaryThreadTagInputs.allSatisfy({ $0["value"] != secondaryThreadTagID }) {
                throw AwfulCoreError.parseError(description: "Could not find secondary thread tag")
            }
            try form.select(value: secondaryThreadTagID, for: secondaryName)
        }
        
        let submission = form.submit(button: formData.form.submitButton(named: "submit"))
        let postParams = prepareFormEntries(submission)
        
        // Submit the new thread
        let (data, response) = try await fetch(method: .post, urlString: "newthread.php", parameters: postParams)
        let (document, _) = try parseHTML(data: data, response: response)
        
        guard let link = document.firstNode(matchingSelector: "a[href *= 'showthread']"),
              let href = link["href"],
              let components = URLComponents(string: href),
              let threadID = components.queryItems?.first(where: { $0.name == "threadid" })?.value
        else {
            throw AwfulCoreError.parseError(description: "Could not find new thread ID")
        }
        
        // Create the thread in Core Data
        let backgroundThreadObjectID = await backgroundContext.perform {
            let thread = AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), in: backgroundContext)
            thread.title = subject
            
            let forumFetch = NSFetchRequest<Forum>(entityName: "Forum")
            forumFetch.predicate = NSPredicate(format: "forumID == %@", forumID)
            if let forum = try? backgroundContext.fetch(forumFetch).first {
                thread.forum = forum
            }
            
            if let threadTagID = threadTagID {
                let tagFetch = NSFetchRequest<ThreadTag>(entityName: "ThreadTag")
                tagFetch.predicate = NSPredicate(format: "threadTagID == %@", threadTagID)
                if let tag = try? backgroundContext.fetch(tagFetch).first {
                    thread.threadTag = tag
                }
            }
            
            if let secondaryThreadTagID = secondaryThreadTagID {
                let tagFetch = NSFetchRequest<ThreadTag>(entityName: "ThreadTag")
                tagFetch.predicate = NSPredicate(format: "threadTagID == %@", secondaryThreadTagID)
                if let tag = try? backgroundContext.fetch(tagFetch).first {
                    thread.secondaryThreadTag = tag
                }
            }
            
            try? backgroundContext.save()
            return thread.objectID
        }
        
        return await mainContext.perform {
            mainContext.object(with: backgroundThreadObjectID) as! AwfulThread
        }
    }
    
    /// Previews the original post for a new thread using forum ID (Sendable-safe)
    public func previewOriginalPostForThread(
        forumID: String,
        bbcode: String,
        subject: String,
        threadTagID: String? = nil,
        secondaryThreadTagID: String? = nil
    ) async throws -> String {
        // Get the form data
        let formData: PostNewThreadFormData
        do {
            let (data, response) = try await fetch(method: .get, urlString: "newthread.php", parameters: [
                "action": "newthread",
                "forumid": forumID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            let htmlForm = try document.requiredNode(matchingSelector: "form[name = 'vbform']")
            formData = try PostNewThreadFormData(htmlForm, url: url)
        }
        
        // Prepare form submission for preview
        let form = SubmittableForm(formData.form)
        try form.enter(text: subject, for: "subject")
        try form.enter(text: bbcode, for: "message")
        
        if let threadTagID = threadTagID {
            try form.select(value: threadTagID, for: formData.threadTagName)
        }
        
        if let secondaryThreadTagID = secondaryThreadTagID,
           let secondaryName = formData.secondaryThreadTagName {
            try form.select(value: secondaryThreadTagID, for: secondaryName)
        }
        
        let submission = form.submit(button: formData.form.submitButton(named: "preview"))
        let params = prepareFormEntries(submission)
        
        // Get the preview
        let (data, response) = try await fetch(method: .post, urlString: "newthread.php", parameters: params)
        let (document, _) = try parseHTML(data: data, response: response)
        
        guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
            throw AwfulCoreError.parseError(description: "Could not find previewed post")
        }
        
        workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
        return postbody.innerHTML
    }
}

// MARK: - Private Message Reading with Sendable Types

extension ForumsClient {
    
    /// Reads a private message using message ID (Sendable-safe)
    public func readPrivateMessage(
        messageID: String
    ) async throws -> String {
        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: [
            "action": "show",
            "privatemessageid": messageID,
        ])
        let (document, _) = try parseHTML(data: data, response: response)
        
        guard let postbody = document.firstNode(matchingSelector: "#postbody") else {
            throw AwfulCoreError.parseError(description: "Could not find private message content")
        }
        
        workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
        return postbody.innerHTML
    }
}
