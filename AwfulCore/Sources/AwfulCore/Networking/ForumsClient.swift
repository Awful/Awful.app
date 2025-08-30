//  ForumsClient.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulScraping
import CoreData
import Foundation
import HTMLReader
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsClient")

/// Sends data to and scrapes data from the Something Awful Forums.
public final class ForumsClient {
    internal var backgroundManagedObjectContext: NSManagedObjectContext?
    private var lastModifiedObserver: LastModifiedContextObserver?
    private var urlSession: URLSession?

    /// A block to call when the login session is destroyed. Not called when logging out from Awful.
    public var didRemotelyLogOut: (() -> Void)?

    /// Convenient singleton.
    public static let shared = ForumsClient()
    private init() {}
    
    /**
     The Forums endpoint for the client. Typically https://forums.somethingawful.com

     Setting a new baseURL cancels all in-flight requests.
     */
    public var baseURL: URL? {
        didSet {
            guard oldValue != baseURL else { return }
            urlSession?.invalidateAndCancel()
            urlSession = nil

            if baseURL != nil {
                let config = URLSessionConfiguration.default
                var headers = config.httpAdditionalHeaders ?? [:]
                headers["User-Agent"] = awfulUserAgent
                config.httpAdditionalHeaders = headers

#if DEBUG
                let protocolClasses = [FixtureURLProtocol.self] + (config.protocolClasses ?? [])
                config.protocolClasses = protocolClasses
#endif

                urlSession = URLSession(configuration: config, delegate: CachebustingSessionDelegate(), delegateQueue: nil)
            }
        }
    }

    /// A managed object context into which data is imported after scraping.
    public var managedObjectContext: NSManagedObjectContext? {
        didSet {
            if let oldValue = oldValue {
                NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: oldValue)
            }
            if let oldBackground = backgroundManagedObjectContext {
                NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: oldBackground)
                backgroundManagedObjectContext = nil
                lastModifiedObserver = nil
            }
            
            guard let newValue = managedObjectContext else { return }

            NotificationCenter.default.addObserver(self, selector: #selector(mainManagedObjectContextDidSave), name: .NSManagedObjectContextDidSave, object: newValue)

            let background = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            backgroundManagedObjectContext = background
            background.persistentStoreCoordinator = newValue.persistentStoreCoordinator
            NotificationCenter.default.addObserver(self, selector: #selector(backgroundManagedObjectContextDidSave), name: .NSManagedObjectContextDidSave, object: background)

            lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: background)
        }
    }

    @objc private func mainManagedObjectContextDidSave(_ notification: Notification) {
        guard let context = backgroundManagedObjectContext else { return }
        context.perform { context.mergeChanges(fromContextDidSave: notification) }
    }

    @objc private func backgroundManagedObjectContextDidSave(_ notification: Notification) {
        guard let context = managedObjectContext else { return }

        let updatedObjectIDs: [NSManagedObjectID] = {
            guard
                let userInfo = notification.userInfo,
                let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>
                else { return [] }
            return updatedObjects.map { $0.objectID }
        }()

        context.perform {
            updatedObjectIDs
                .compactMap { context.object(with: $0) }
                .forEach { $0.willAccessValue(forKey: nil) }
            
            context.mergeChanges(fromContextDidSave: notification)
        }
    }

    private var loginCookie: HTTPCookie? {
        baseURL
            .flatMap { urlSession?.configuration.httpCookieStorage?.cookies(for: $0) }?
            .first { $0.name == "bbuserid" }
    }

    /// Whether or not a valid, logged-in session exists.
    public var isLoggedIn: Bool {
        loginCookie != nil
    }
    
    /// When the valid, logged-in session expires.
    public var loginCookieExpiryDate: Date? {
        loginCookie?.expiresDate
    }

    enum Error: Swift.Error {
        case failedTransferToMainContext
        case missingURLSession
        case invalidBaseURL
        case missingDataAndError
        case missingManagedObjectContext
        case requestSerializationError(String)
        case unexpectedContentType(String, expected: String)
    }

    internal enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    internal func fetch(
        method: Method,
        urlString: String,
        parameters: some Sequence<KeyValuePairs<String, Any>.Element>,
        willRedirect: @escaping (_ response: HTTPURLResponse, _ newRequest: URLRequest) async -> URLRequest? = { $1 }
    ) async throws -> (Data, URLResponse) {
        guard let urlSession else {
            throw Error.missingURLSession
        }

        let wasLoggedIn = isLoggedIn

        let result: Result<(Data, URLResponse), Swift.Error>
        do {
            guard let url = URL(string: urlString, relativeTo: baseURL),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            else { throw ForumsClient.Error.invalidBaseURL }

            let parameters = parameters.lazy.map(win1252Escaped(_:))

            var request: URLRequest
            switch method {
            case .get:
                var queryItems = components.queryItems ?? []
                queryItems.append(contentsOf: parameters.map { URLQueryItem(name: $0, value: $1) })
                var components = components
                components.queryItems = queryItems
                request = URLRequest(url: components.url!)

            case .post:
                request = URLRequest(url: url)
                try request.setMultipartFormData(parameters, encoding: .windowsCP1252)
            }
            request.httpMethod = method.rawValue
            let tuple = try await urlSession.data(for: request, willRedirect: willRedirect)
            result = .success(tuple)
        } catch {
            result = .failure(error)
        }

        if wasLoggedIn, !isLoggedIn, let didRemotelyLogOut {
            Task { @MainActor in
                didRemotelyLogOut()
            }
        }

        return try result.get()
    }

    // MARK: Forums Session

    public func logIn(
        username: String,
        password: String
    ) async throws -> User {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }

        // Not that we'll parse any JSON from the login attempt, but tacking `json=1` on to `urlString` might avoid pointless server-side rendering.
        let (data, response) = try await fetch(method: .post, urlString: "account.php?json=1", parameters: [
            "action": "login",
            "username": username,
            "password" : password,
            "next": "/index.php?json=1",
        ])
        do {
            _ = try JSONDecoder().decode(IndexScrapeResult.self, from: data)
        } catch {
            // We can fail to decode JSON when the server responds with an error as HTML. We may actually be logged in despite the error (e.g. a banned user can "log in" but do basically nothing). However, subsequent launches will crash because we don't actually store the logged-in user's ID. We can avoid the crash by clearing cookies, so we seem logged out.
            urlSession?.configuration.httpCookieStorage?.removeCookies(since: .distantPast)

            if let error = error as? DecodingError,
               case .dataCorrupted = error
            {
                // Response data was not JSON. Maybe it was a server error delivered as HTML?
                _ = try parseHTML(data: data, response: response)
            }
            
            // We couldn't figure out a more helpful error, so throw the decoding error.
            throw error
        }
        let backgroundUserObjectID = try await backgroundContext.perform {
            // Reparse the result inside the closure to avoid capturing non-Sendable type
            let innerResult = try JSONDecoder().decode(IndexScrapeResult.self, from: data)
            let managed = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return managed.currentUser.objectID
        }
        return try await mainContext.perform {
            guard let user = mainContext.object(with: backgroundUserObjectID) as? User else {
                throw Error.failedTransferToMainContext
            }
            return user
        }
    }

    // MARK: Forums

    public func taxonomizeForums() async throws {
        guard let context = backgroundManagedObjectContext else {
            throw Error.missingManagedObjectContext
        }
        let (data, _) = try await fetch(method: .get, urlString: "index.php?json=1", parameters: [])
        // Parse outside to validate
        _ = try JSONDecoder().decode(IndexScrapeResult.self, from: data)
        try await context.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let innerResult = try JSONDecoder().decode(IndexScrapeResult.self, from: data)
            try innerResult.upsert(into: context)
            try context.save()
        }
    }

    // MARK: Search

    /// Fetches the initial search page form with forum list and search options.
    /// - Returns: HTMLDocument containing the search form
    public func fetchSearchPage() async throws -> HTMLDocument {
        let (data, response) = try await fetch(method: .get, urlString: "query.php", parameters: [:])
        let (document, _) = try parseHTML(data: data, response: response)
        return document
    }



    /// Performs a forum search with the given query and selected forum IDs.
    /// - Parameters:
    ///   - query: The search query string
    ///   - forumIDs: Array of forum ID strings to search within
    /// - Returns: HTMLDocument containing the search results
    public func searchForums(
        query: String,
        forumIDs: [String]
    ) async throws -> HTMLDocument {
        guard let urlSession else { throw Error.missingURLSession }
        guard let baseURL else { throw Error.invalidBaseURL }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw Error.invalidBaseURL
        }

        components.path = "/query.php"
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "action", value: "query")
        ]
        queryItems.append(contentsOf: forumIDs.map { URLQueryItem(name: "forums[]", value: $0) })
        components.queryItems = queryItems

        guard let url = components.url,
              let queryString = components.percentEncodedQuery?.data(using: .utf8)
        else {
            throw Error.requestSerializationError("Could not create search query string")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = queryString

        let (data, response) = try await urlSession.data(for: request)
        let (document, _) = try parseHTML(data: data, response: response)
        return document
    }

    /// Navigates to a specific page of forum search results.
    /// - Parameters:
    ///   - queryID: The search query ID from the initial search
    ///   - page: The page number to navigate to
    /// - Returns: HTMLDocument containing the search results for the specified page
    public func searchForumsPage(
        queryID: String,
        page: Int
    ) async throws -> HTMLDocument {
        let (data, response) = try await fetch(method: .get, urlString: "query.php", parameters: [
            "action": "results",
            "qid": queryID,
            "page": String(page)
        ])
        let (document, _) = try parseHTML(data: data, response: response)
        return document
    }

    // MARK: Threads

    /// - Parameter tagged: A thread tag to use for filtering forums, or `nil` for no filtering.
    public func listThreads(
        in forum: Forum,
        tagged threadTag: ThreadTag? = nil,
        page: Int
    ) async throws -> [AwfulThread] {
        let context = forum.managedObjectContext!
        let forumObjectID = forum.objectID
        let threadTagObjectID = threadTag?.objectID
        
        let (forumID, threadTagID) = await context.perform {
            let forumObj = context.object(with: forumObjectID) as! Forum
            let threadTagObj = threadTagObjectID.map { context.object(with: $0) as! ThreadTag }
            return (forumObj.forumID, threadTagObj?.threadTagID)
        }
        return try await listThreads(
            forumID: forumID,
            threadTagID: threadTagID,
            page: page
        )
    }

    public func listBookmarkedThreads(
        page: Int
    ) async throws -> [AwfulThread] {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "bookmarkthreads.php", parameters: [
            "action": "view",
            "perpage": "40",
            "pagenumber": "\(page)",
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        // Parse outside to validate
        _ = try ThreadListScrapeResult(document, url: url)
        
        let backgroundThreadObjectIDs = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try ThreadListScrapeResult(innerDocument, url: innerUrl)
            let threads = try innerResult.upsert(into: backgroundContext)

            AwfulThread.fetch(in: backgroundContext) {
                let threadIDsToIgnore = threads.map { $0.threadID }
                $0.predicate = .and(
                    .init("\(\AwfulThread.bookmarked) = YES"),
                    .init("\(\AwfulThread.bookmarkListPage) >= \(page)"),
                    .init("NOT(\(\AwfulThread.threadID) IN \(threadIDsToIgnore))")
                )
            }.forEach { $0.bookmarkListPage = 0 }

            try backgroundContext.save()
            return threads.map { $0.objectID }
        }
        return await mainContext.perform {
            backgroundThreadObjectIDs.compactMap { mainContext.object(with: $0) as? AwfulThread }
        }
    }

    public func setThread(
        _ thread: AwfulThread,
        isBookmarked: Bool
    ) async throws {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        try await setThread(threadID: threadID, isBookmarked: isBookmarked)
    }

    public func rate(
        _ thread: AwfulThread,
        as rating: Int
    ) async throws {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        try await rate(threadID: threadID, rating: rating)
    }

    public func setBookmarkColor(
        _ thread: AwfulThread,
        as category: StarCategory
    ) async throws {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        try await setBookmarkColor(threadID: threadID, category: category)
    }

    public func markThreadAsSeenUpTo(
        _ post: Post
    ) async throws {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postInfo = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postInfo
        }
        try await markThreadAsSeenUpTo(postInfo: postInfo)
    }

    public func markUnread(
        _ thread: AwfulThread
    ) async throws {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        try await markUnread(threadID: threadID)
    }

    public func listAvailablePostIcons(
        inForumIdentifiedBy forumID: String
    ) async throws -> (primary: [ThreadTag], secondary: [ThreadTag]) {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "newthread.php", parameters: [
            "action": "newthread",
            "forumid": forumID,
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        // Parse outside to validate
        _ = try PostIconListScrapeResult(document, url: url)
        
        let backgroundTags = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PostIconListScrapeResult(innerDocument, url: innerUrl)
            let managed = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return (primary: managed.primary.map { $0.objectID }, secondary: managed.secondary.map { $0.objectID })
        }
        return await mainContext.perform {
            (
                primary: backgroundTags.primary.compactMap { mainContext.object(with: $0) as? ThreadTag },
                secondary: backgroundTags.secondary.compactMap { mainContext.object(with: $0) as? ThreadTag }
            )
        }
    }

    /// - Parameter postData: A `PostNewThreadFormData` returned by `previewOriginalPostForThread(in:bbcode:)`.
    public func postThread(
        using formData: PostNewThreadFormData,
        subject: String,
        threadTag someThreadTag: ThreadTag?,
        secondaryTag someSecondaryTag: ThreadTag?,
        bbcode: String
    ) async throws -> AwfulThread {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }

        // Extract tag object IDs if present
        let tagObjectID = someThreadTag?.objectID
        let secondaryTagObjectID = someSecondaryTag?.objectID
        
        // Extract post icon data before closure
        let primaryIcons = formData.postIcons.primaryIcons
        let secondaryIcons = formData.postIcons.secondaryIcons
        let selectedPrimaryIconFormName = formData.postIcons.selectedPrimaryIconFormName
        let selectedSecondaryIconFormName = formData.postIcons.selectedSecondaryIconFormName

        // We can't capture formData.postIcons directly as it's not Sendable
        // Instead, we'll handle tag image names outside the closure
        let tagImageName: String?
        let secondaryTagImageName: String?
        
        if let tagObjectID = tagObjectID {
            tagImageName = await backgroundContext.perform {
                let tag = backgroundContext.object(with: tagObjectID) as? ThreadTag
                return tag?.imageName
            }
        } else {
            tagImageName = nil
        }
        
        if let secondaryTagObjectID = secondaryTagObjectID {
            secondaryTagImageName = await backgroundContext.perform {
                let tag = backgroundContext.object(with: secondaryTagObjectID) as? ThreadTag
                return tag?.imageName
            }
        } else {
            secondaryTagImageName = nil
        }
        
        // Save post icons to background context
        // We can't pass formData.postIcons directly, so we'll skip this upsert
        // since the icons are already in the database from when the form was loaded
        
        let form = SubmittableForm(formData.form)
        try form.enter(text: subject, for: "subject")
        try form.enter(text: bbcode, for: "message")
        if let tagImageName,
           let icon = primaryIcons.first(where: { $0.url.map(ThreadTag.imageName) == tagImageName }),
           !selectedPrimaryIconFormName.isEmpty
       {
           try form.select(value: icon.id, for: selectedPrimaryIconFormName)
       }
        if let secondaryTagImageName,
           let icon = secondaryIcons.first(where: { $0.url.map(ThreadTag.imageName) == secondaryTagImageName }),
           !selectedSecondaryIconFormName.isEmpty
       {
           try form.select(value: icon.id, for: selectedSecondaryIconFormName)
       }
        let submission = form.submit(button: formData.form.submitButton(named: "submit"))
        let params = prepareFormEntries(submission)
        let (data, response) = try await fetch(method: .post, urlString: "newthread.php", parameters: params)
        let (document, _) = try parseHTML(data: data, response: response)
        guard let link = document.firstNode(matchingSelector: "a[href *= 'showthread']"),
              let href = link["href"],
              let components = URLComponents(string: href),
              let queryItems = components.queryItems,
              let threadIDPair = queryItems.first(where: { $0.name == "threadid" }),
              let threadID = threadIDPair.value
        else {
            throw AwfulCoreError.parseError(description: "The new thread could not be located. Maybe it didn't actually get made. Double-check if your thread has appeared, then try again.")
        }
        return await mainContext.perform {
            AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), in: mainContext)
        }
    }

    public struct PostNewThreadFormData {
        internal let form: Form
        internal let postIcons: PostIconListScrapeResult
        internal let threadTagName: String
        internal let threadTagInputs: [HTMLElement]
        internal let secondaryThreadTagName: String?
        internal let secondaryThreadTagInputs: [HTMLElement]
        
        internal init(_ htmlForm: HTMLElement, url: URL?) throws {
            self.form = try Form(htmlForm, url: url)
            self.postIcons = try PostIconListScrapeResult(htmlForm.document!, url: url)
            
            // Extract thread tag information
            if let primaryGroup = htmlForm.firstNode(matchingSelector: "input[name='iconid']")?.parent {
                self.threadTagName = "iconid"
                self.threadTagInputs = primaryGroup.nodes(matchingSelector: "input[name='iconid']")
            } else {
                self.threadTagName = "iconid"
                self.threadTagInputs = []
            }
            
            if let secondaryGroup = htmlForm.firstNode(matchingSelector: "input[name='posticonid']")?.parent {
                self.secondaryThreadTagName = "posticonid"
                self.secondaryThreadTagInputs = secondaryGroup.nodes(matchingSelector: "input[name='posticonid']")
            } else {
                self.secondaryThreadTagName = nil
                self.secondaryThreadTagInputs = []
            }
        }
    }

    /// - Returns: The promise of the previewed post's HTML.
    public func previewOriginalPostForThread(
        in forum: Forum,
        bbcode: String
    ) async throws -> (previewHTML: String, formData: PostNewThreadFormData) {
        let previewParameters: [KeyValuePairs<String, Any>.Element]
        do {
            // Extract forumID before any closures
            let context = forum.managedObjectContext!
            let forumObjectID = forum.objectID
            let forumID: String = await context.perform {
                let forumObj = context.object(with: forumObjectID) as! Forum
                return forumObj.forumID
            }
            let (data, response) = try await fetch(method: .get, urlString: "newthread.php", parameters: [
                "action": "newthread",
                "forumid": forumID,
            ])
            let (document, url) = try parseHTML(data: data, response: response)
            guard let htmlForm = document.firstNode(matchingSelector: "form[name = 'vbform']") else {
                if
                    let specialMessage = document.firstNode(matchingSelector: "#content center div.standard"),
                    specialMessage.textContent.contains("accepting")
                {
                    throw AwfulCoreError.forbidden(description: "You're not allowed to post threads in this forum")
                }
                else {
                    throw AwfulCoreError.parseError(description: "Could not find new thread form")
                }
            }

            let form = try Form(htmlForm, url: url)
            let submittable = SubmittableForm(form)

            try submittable.enter(text: bbcode, for: "message")

            let submission = submittable.submit(button: form.submitButton(named: "preview"))
            previewParameters = prepareFormEntries(submission)
        }

        try Task.checkCancellation()

        do {
            let (data, response) = try await fetch(method: .post, urlString: "newthread.php", parameters: previewParameters)
            let (document, url) = try parseHTML(data: data, response: response)
            guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
                throw AwfulCoreError.parseError(description: "Could not find previewed original post")
            }
            workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)

            let htmlForm = try document.requiredNode(matchingSelector: "form[name = 'vbform']")
            let postData = try PostNewThreadFormData(htmlForm, url: url)
            return (previewHTML: postbody.innerHTML, formData: postData)
        }
    }
    
    /**
     Returns info for a random flag image that can sit atop a page of posts in a thread.
     
     Generally only seen in FYAD.
     */
    public func flagForThread(
        in forum: Forum
    ) async throws -> Flag {
        // Extract forumID properly
        let context = forum.managedObjectContext!
        let forumObjectID = forum.objectID
        let forumID: String = await context.perform {
            let forumObj = context.object(with: forumObjectID) as! Forum
            return forumObj.forumID
        }
        let (data, _) = try await fetch(method: .get, urlString: "flag.php", parameters: [
            "forumid": forumID,
        ])
        return try JSONDecoder().decode(Flag.self, from: data)
    }
    
    public struct Flag: Decodable {
        public let created: String?
        public let path: String
        public let username: String?
    }

    // MARK: Announcements

    /**
     Populates already-scraped announcements with their `bodyHTML`.
     
     - Note: Announcements must first be scraped as part of a thread list for this method to do anything.
     */
    public func listAnnouncements() async throws -> [Announcement] {
        guard let backgroundContext = backgroundManagedObjectContext,
              let mainContext = managedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "announcement.php", parameters: [
            "forumid": "1",
        ])
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try AnnouncementListScrapeResult(document, url: url)
        
        let backgroundAnnouncements = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try AnnouncementListScrapeResult(innerDocument, url: innerUrl)
            let announcements = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return announcements.map { $0.objectID }
        }
        return await mainContext.perform {
            backgroundAnnouncements.compactMap { mainContext.object(with: $0) as? Announcement }
        }
    }

    // MARK: Posts

    /**
     - Parameter writtenBy: A `User` whose posts should be the only ones listed. If `nil`, posts from all authors are listed.
     - Parameter updateLastReadPost: If `true`, the "last read post" marker on the Forums is updated to include the posts loaded on the page (which is probably what you want). If `false`, the next time the user asks for "next unread post" they'll get the same answer again.
     - Returns: A cancellable promise of:
         - posts: The posts that appeared on the page of the thread.
         - firstUnreadPost: The index of the first unread post on the page (this index starts at 1), or `nil` if no unread post is found.
         - advertisementHTML: Raw HTML of an SA-hosted banner ad.
     */
    public func listPosts(
        in thread: AwfulThread,
        writtenBy author: User?,
        page: ThreadPage,
        updateLastReadPost: Bool
    ) async throws -> (posts: [Post], firstUnreadPost: Int?, advertisementHTML: String) {
        // Extract thread info and delegate to Sendable version
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadInfo = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadInfo
        }
        
        let authorUserID: String?
        if let author = author {
            let authorContext = author.managedObjectContext!
            let authorObjectID = author.objectID
            authorUserID = await authorContext.perform {
                let authorObj = authorContext.object(with: authorObjectID) as! User
                return authorObj.userID
            }
        } else {
            authorUserID = nil
        }
        
        let result = try await listPosts(
            threadInfo: threadInfo,
            authorUserID: authorUserID,
            page: page,
            updateLastReadPost: updateLastReadPost
        )
        
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }
        
        let posts = await mainContext.perform {
            result.postObjectIDs.compactMap { mainContext.object(with: $0) as? Post }
        }
        
        return (posts: posts, firstUnreadPost: result.firstUnreadPost, advertisementHTML: result.advertisementHTML)
    }

    /**
     - Parameter post: An ignored post whose author and innerHTML should be filled.
     */
    public func readIgnoredPost(
        _ post: Post
    ) async throws {
        guard let backgroundContext = backgroundManagedObjectContext,
              let postContext = post.managedObjectContext
        else { throw Error.missingManagedObjectContext }

        // Extract post ID before closure
        let postObjectID = post.objectID
        let postID: String = await postContext.perform {
            let postObj = postContext.object(with: postObjectID) as! Post
            return postObj.postID
        }
        
        let (data, response) = try await fetch(method: .get, urlString: "showthread.php", parameters: [
            "action": "showpost",
            "postid": postID,
        ])
        
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try ShowPostScrapeResult(document, url: url)
        
        try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try ShowPostScrapeResult(innerDocument, url: innerUrl)
            _ = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
        }
        await postContext.perform {
            let postObj = postContext.object(with: postObjectID)
            postContext.refresh(postObj, mergeChanges: true)
        }
    }

    public enum ReplyLocation {
        case lastPostInThread
        case post(Post)
    }

    public func reply(
        to thread: AwfulThread,
        bbcode: String
    ) async throws -> ReplyLocation {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        return try await reply(threadID: threadID, bbcode: bbcode)
    }

    public func previewReply(
        to thread: AwfulThread,
        bbcode: String
    ) async throws -> String {
        let context = thread.managedObjectContext!
        let threadObjectID = thread.objectID
        let threadID = await context.perform {
            let threadObj = context.object(with: threadObjectID) as! AwfulThread
            return threadObj.threadID
        }
        return try await previewReply(threadID: threadID, bbcode: bbcode)
    }

    public func findBBcodeContents(
        of post: Post
    ) async throws -> String {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID: String = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
        let (data, response) = try await fetch(method: .get, urlString: "editpost.php", parameters: [
            "action": "editpost",
            "postid": postID,
        ])
        let document = try parseHTML(data: data, response: response)
        return try findMessageText(in: document)
    }

    public func quoteBBcodeContents(of post: Post) async throws -> String {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID: String = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
        let (data, response) = try await fetch(method: .get, urlString: "newreply.php", parameters: [
            "action": "newreply",
            "postid": postID,
        ])
        let parsed = try parseHTML(data: data, response: response)
        return try findMessageText(in: parsed)
    }

    public func edit(
        _ post: Post,
        bbcode: String
    ) async throws {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
        try await edit(postID: postID, bbcode: bbcode)
    }

    private func editForm(
        for post: Post
    ) async throws -> Form {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID: String = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
        let (data, response) = try await fetch(method: .get, urlString: "editpost.php", parameters: [
            "action": "editpost",
            "postid": postID,
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        guard let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']") else {
            if let specialMessage = document.firstNode(matchingSelector: "#content center div.standard"),
               specialMessage.textContent.contains("permission")
            {
                throw AwfulCoreError.forbidden(description: "You're not allowed to edit posts in this thread")
            } else {
                throw AwfulCoreError.parseError(description: "Failed to edit post; could not find form")
            }
        }
        return try Form(htmlForm, url: url)
    }

    /**
     - Parameter postID: The post's ID. Specified directly in case no such post exists, which would make for a useless `Post`.
     - Returns: The promise of a post (with its `thread` set) and the page containing the post (may be `AwfulThreadPage.last`).
     */
    public func locatePost(
        id postID: String,
        updateLastReadPost: Bool
    ) async throws -> (post: Post, page: ThreadPage) {
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }

        // The SA Forums redirects to a URL with the info we need, so we'll watch for that and then cancel the load (we don't actually want the content).
        var result: (threadID: String, page: ThreadPage)?
        func redirect(response: HTTPURLResponse, newRequest: URLRequest) -> URLRequest? {
            guard let url = newRequest.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let threadID = components.queryItems?.first(where: { $0.name == "threadid" })?.value,
                  !threadID.isEmpty,
                  let rawPagenumber = components.queryItems?.first(where: { $0.name == "pagenumber" })?.value,
                  let pageNumber = Int(rawPagenumber)
            else { return newRequest }

            result = (threadID: threadID, page: .specific(pageNumber))
            return nil
        }
        do {
            _ = try await fetch(method: .get, urlString: "showthread.php", parameters: [
                "goto": "post",
                "postid": postID,
                "noseen": updateLastReadPost ? "0" : "1",
            ], willRedirect: redirect)
        } catch URLError.cancelled {
            // ok so long as we got the info.
        }
        guard let (threadID, page) = result else {
            throw AwfulCoreError.parseError(description: "The thread ID or page number could not be found")
        }

        return try await mainContext.perform {
            let post = Post.objectForKey(objectKey: PostKey(postID: postID), in: mainContext)
            let thread = AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), in: mainContext)

            post.thread = thread
            try mainContext.save()

            return (post: post, page: page)
        }
    }

    public func previewEdit(
        to post: Post,
        bbcode: String
    ) async throws -> String {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
        return try await previewEdit(postID: postID, bbcode: bbcode)
    }

    /**
     - Parameter reason: A further explanation of what's wrong with the post.
     */
    public func report(
        _ post: Post,
        nws: Bool,
        reason: String
    ) async throws {
        let context = post.managedObjectContext!
        let postObjectID = post.objectID
        let postID: String = await context.perform {
            let postObj = context.object(with: postObjectID) as! Post
            return postObj.postID
        }
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

    // MARK: Users

    internal func profile(
        parameters: some Sequence<KeyValuePairs<String, Any>.Element>
    ) async throws -> Profile {
        guard let backgroundContext = backgroundManagedObjectContext else {
            throw Error.missingManagedObjectContext
        }

        let (data, response) = try await fetch(method: .get, urlString: "member.php", parameters: parameters)
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try ProfileScrapeResult(document, url: url)
        
        return try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try ProfileScrapeResult(innerDocument, url: innerUrl)
            let profile = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return profile
        }
    }

    public func profileLoggedInUser() async throws -> User {
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }

        let backgroundProfile = try await profile(parameters: ["action": "getinfo"])
        let profileObjectID = backgroundProfile.objectID
        return try await mainContext.perform {
            guard let profile = mainContext.object(with: profileObjectID) as? Profile else {
                throw AwfulCoreError.parseError(description: "Could not save profile")
            }

            return profile.user
        }
    }

    public func profileUser(
        _ request: UserProfileSearchRequest
    ) async throws -> Profile {
        guard let mainContext = managedObjectContext else {
            throw Error.missingManagedObjectContext
        }

        var parameters = ["action": "getinfo"]
        switch request {
        case let .userID(userID, username: username):
            parameters["userid"] = userID
            if let username {
                parameters["username"] = username
            }
        case .username(let username):
            parameters["username"] = username
        }

        let backgroundProfile = try await profile(parameters: parameters)
        let profileObjectID = backgroundProfile.objectID
        return try await mainContext.perform {
            guard let profile = mainContext.object(with: profileObjectID) as? Profile else {
                throw AwfulCoreError.parseError(description: "Could not save profile")
            }
            return profile
        }
    }

    public enum UserProfileSearchRequest {
        case userID(String, username: String? = nil)
        case username(String)
    }

    internal func lepersColony(
        parameters: some Sequence<KeyValuePairs<String, Any>.Element>
    ) async throws -> [LepersColonyScrapeResult.Punishment] {
        let (data, response) = try await fetch(method: .get, urlString: "banlist.php", parameters: parameters)
        let (document, url) = try parseHTML(data: data, response: response)
        // Extract punishments data before any async operations
        let result = try LepersColonyScrapeResult(document, url: url)
        return result.punishments
    }

    public func listPunishments(
        of user: User?,
        page: Int
    ) async throws -> [LepersColonyScrapeResult.Punishment] {
        guard let user else {
            return try await lepersColony(parameters: ["pagenumber": "\(page)"])
        }

        let context = user.managedObjectContext!
        let userObjectID = user.objectID
        let maybe: (userID: String, username: String?) = await context.perform {
            let userObj = context.object(with: userObjectID) as! User
            return (userID: userObj.userID, username: userObj.username)
        }
        let userID: String
        if !maybe.userID.isEmpty {
            userID = maybe.userID
        } else {
            guard let username = maybe.username else {
                assertionFailure("need user ID or username")
                return try await lepersColony(parameters: ["pagenumber": "\(page)"])
            }
            let profile = try await profileUser(.username(username))
            let profileContext = profile.managedObjectContext!
            let profileObjectID = profile.objectID
            userID = await profileContext.perform {
                let profileObj = profileContext.object(with: profileObjectID) as! Profile
                return profileObj.user.userID
            }
        }

        return try await lepersColony(parameters: [
            "pagenumber": "\(page)",
            "userid": userID,
        ])
    }

    // MARK: Private Messages

    public func listPrivateMessagesInInbox() async throws -> [PrivateMessage] {
        guard let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: [])
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try PrivateMessageFolderScrapeResult(document, url: url)
        
        let backgroundMessages = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PrivateMessageFolderScrapeResult(innerDocument, url: innerUrl)
            let messages = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return messages.map { $0.objectID }
        }
        return await mainContext.perform {
            backgroundMessages.compactMap { mainContext.object(with: $0) as? PrivateMessage }
        }
    }

    public func deletePrivateMessage(
        _ message: PrivateMessage
    ) async throws {
        let context = message.managedObjectContext!
        let messageObjectID = message.objectID
        let messageID: String = await context.perform {
            let messageObj = context.object(with: messageObjectID) as! PrivateMessage
            return messageObj.messageID
        }
        let (data, response) = try await fetch(method: .post, urlString: "private.php", parameters: [
            "action": "dodelete",
            "privatemessageid": messageID,
            "delete": "yes",
        ])
        let (document, _) = try parseHTML(data: data, response: response)
        try checkServerErrors(document)
    }

    public func readPrivateMessage(
        identifiedBy messageKey: PrivateMessageKey
    ) async throws -> PrivateMessage {
        guard let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: [
            "action": "show",
            "privatemessageid": messageKey.messageID,
        ])
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try PrivateMessageScrapeResult(document, url: url)
        
        let backgroundMessage = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PrivateMessageScrapeResult(innerDocument, url: innerUrl)
            let message = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return message.objectID
        }
        return try await mainContext.perform {
            guard let privateMessage = mainContext.object(with: backgroundMessage) as? PrivateMessage else {
                throw AwfulCoreError.parseError(description: "Could not save message")
            }
            return privateMessage
        }
    }

    public func quoteBBcodeContents(
        of message: PrivateMessage
    ) async throws -> String {
        let context = message.managedObjectContext!
        let messageObjectID = message.objectID
        let messageID: String = await context.perform {
            let messageObj = context.object(with: messageObjectID) as! PrivateMessage
            return messageObj.messageID
        }
        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: [
            "action": "newmessage",
            "privatemessageid": messageID,
        ])
        let parsed = try parseHTML(data: data, response: response)
        return try findMessageText(in: parsed)
    }

    public func listAvailablePrivateMessageThreadTags() async throws -> [ThreadTag] {
        guard let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext
        else { throw Error.missingManagedObjectContext }

        let (data, response) = try await fetch(method: .get, urlString: "private.php", parameters: ["action": "newmessage"])
        // Parse outside to validate
        let (document, url) = try parseHTML(data: data, response: response)
        _ = try PostIconListScrapeResult(document, url: url)
        
        let backgroundTags = try await backgroundContext.perform {
            // Reparse inside the closure to avoid capturing non-Sendable type
            let (innerDocument, innerUrl) = try parseHTML(data: data, response: response)
            let innerResult = try PostIconListScrapeResult(innerDocument, url: innerUrl)
            let managed = try innerResult.upsert(into: backgroundContext)
            try backgroundContext.save()
            return managed.primary.map { $0.objectID }
        }
        return await mainContext.perform {
            backgroundTags.compactMap { mainContext.object(with: $0) as? ThreadTag }
        }
    }

    /**
     - Parameters:
        - to: The intended recipient's username. (Requiring a `User` would be unhelpful as the username is typed in and may not actually exist.)
        - regarding: Should be `nil` if `forwarding` parameter is non-`nil`.
        - forwarding: Should be `nil` if `regarding` is non-`nil`.
     */
    public func sendPrivateMessage(
        to username: String,
        subject: String,
        threadTag: ThreadTag?,
        bbcode: String,
        about relevantMessage: RelevantMessage
    ) async throws {
        let threadTagID: String
        if let threadTag = threadTag {
            let context = threadTag.managedObjectContext!
            let tagObjectID = threadTag.objectID
            threadTagID = await context.perform {
                let tagObj = context.object(with: tagObjectID) as! ThreadTag
                return tagObj.threadTagID ?? "0"
            }
        } else {
            threadTagID = "0"
        }
        var parameters: Dictionary<String, Any> = [
            "touser": username,
            "title": subject,
            "iconid": threadTagID,
            "message": bbcode,
            "action": "dosend",
            "savecopy": "yes",
            "submit": "Send Message",
        ]
        switch relevantMessage {
        case .none:
            break
        case .forwarding(let relevant):
            parameters["forward"] = "true"
            let context = relevant.managedObjectContext!
            let relevantObjectID = relevant.objectID
            let messageID: String = await context.perform {
                let relevantObj = context.object(with: relevantObjectID) as! PrivateMessage
                return relevantObj.messageID
            }
            parameters["prevmessageid"] = messageID
        case .replyingTo(let relevant):
            parameters["forward"] = ""
            let context = relevant.managedObjectContext!
            let relevantObjectID = relevant.objectID
            let messageID: String = await context.perform {
                let relevantObj = context.object(with: relevantObjectID) as! PrivateMessage
                return relevantObj.messageID
            }
            parameters["prevmessageid"] = messageID
        }

        _ = try await fetch(method: .post, urlString: "private.php", parameters: parameters)
    }

    public enum RelevantMessage {
        case none
        case forwarding(PrivateMessage)
        case replyingTo(PrivateMessage)
    }

    // MARK: Ignore List
    
    /// - Returns: The promise of a form submittable to `updateIgnoredUsers()`.
    public func listIgnoredUsers() async throws -> IgnoreListForm {
        let (data, response) = try await fetch(method: .get, urlString: "member2.php", parameters: [
            "action": "viewlist",
            "userlist": "ignore",
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        let el = try document.requiredNode(matchingSelector: "form[action = 'member2.php']")
        let form = try Form(el, url: url)
        return try IgnoreListForm(form)
    }
    
    /**
     - Parameter form: An `IgnoreListForm` that originated from a call to `listIgnoredUsers()`.
     - Note: The promise can fail with an `IgnoreListChangeError`, which may be useful to consider separately from the usual network-related errors and `ScrapingError`.
     */
    public func updateIgnoredUsers(
        _ form: IgnoreListForm
    ) async throws {
        let submittable = try form.makeSubmittableForm()
        let parameters = prepareFormEntries(submittable.submit(button: form.submitButton))
        let (data, response) = try await fetch(method: .post, urlString: "member2.php", parameters: parameters)
        let (html, url) = try parseHTML(data: data, response: response)
        switch try IgnoreListChangeScrapeResult(html, url: url) {
        case .success:
            break
        case .failure(let error):
            throw error
        }
    }
    
    /// Attempts to parse the `formkey` string value from a user's profile page (`member.php`)
    /// This page has two formkey elements, one for the buddy list and one for the ignorelist, so we parse using `findIgnoreFormkey`
    /**
     - Parameters:
     - userid: The user we're ignoring's userid
     - action:: Will be `getinfo` while using the profile page (`member.php`) method
     */
    private func getProfilePageIgnoreFormkey(
        userid: String
    ) async throws -> String {
        let (data, response) = try await fetch(method: .get, urlString: "member.php", parameters: [
            "userid": userid,
            "action": "getinfo",
        ])
        let parsed = try parseHTML(data: data, response: response)
        return try findIgnoreFormkey(in: parsed)
    }
    
    /**
     Attempts to add a user to the ignore list using the profile page ignore form.
    
     This allows addition of new ignore list entries without the error caused by a potential preexisting ignore list containing a moderator, so long as this new entry attempt is not themselves a moderator (in which case an error is correct).

     - Parameters:
        - userid: The ignored user's userid
        - action: `addlist` is the action used by the SA profile page (`member.php`) ignore button
        - formkey: Scraped key from profile page (`member.php`) and required for the subsequent member2.php action
        - userlist: Always `ignore` for the ignore list
     */
    public func addUserToIgnoreList(
        userid: String
    ) async throws {
        let formkey = try await getProfilePageIgnoreFormkey(userid: userid)
        let (data, response) = try await fetch(method: .post, urlString: "member2.php", parameters: [
            "userid": userid,
            "action": "addlist",
            "formkey": formkey,
            "userlist": "ignore",
        ])
        let (document, url) = try parseHTML(data: data, response: response)
        switch try IgnoreListChangeScrapeResult(document, url: url) {
        case .success:
            break
        case .failure(let error):
            throw error
        }
    }
    
    /// Attempts to remove a user from the ignore list. This can fail for many reasons, including having a moderator or admin on your ignore list.
    public func removeUserFromIgnoreList(
        username: String
    ) async throws {
        var form = try await listIgnoredUsers()
        guard let i = form.usernames.firstIndex(of: username) else { return }
        form.usernames.remove(at: i)
        try await updateIgnoredUsers(form)
    }
}


/// A (typically network) operation that can be cancelled.
public protocol Cancellable: AnyObject {

    /// Idempotent.
    func cancel()
}

extension Operation: Cancellable {}
extension URLSessionTask: Cancellable {}


internal typealias ParsedDocument = (document: HTMLDocument, url: URL?)

internal func parseHTML(data: Data, response: URLResponse) throws -> ParsedDocument {
    let contentType = (response as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String
    let document = HTMLDocument(data: data, contentTypeHeader: contentType)
    try checkServerErrors(document)
    return (document: document, url: response.url)
}

private func parseJSONDict(data: Data, response: URLResponse) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dict = json as? [String: Any] else {
        throw ForumsClient.Error.unexpectedContentType("\(type(of: json))", expected: "Dictionary<String, Any>")
    }
    return dict
}


internal func workAroundAnnoyingImageBBcodeTagNotMatching(in postbody: HTMLElement) {
    for img in postbody.nodes(matchingSelector: "img[src^='http://awful-image']") {
        if let src = img["src"] {
            let suffix = src.dropFirst("http://".count)
            img["src"] = String(suffix)
        }
    }
}

public enum ServerError: LocalizedError {
    case banned(reason: URL?, help: URL?)
    case databaseUnavailable(title: String, message: String)
    case standard(title: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .banned:
            String(localized: "You've Been Banned", bundle: .module)
        case .databaseUnavailable(title: _, message: let message),
             .standard(title: _, message: let message):
            message
        }
    }

    public var failureReason: String? {
        switch self {
        case .banned:
            String(localized: "Congratulations! Please visit the Something Awful Forums website to learn why you were banned, to contact a mod or admin, to read the rules, or to reactivate your account.")
        case .databaseUnavailable, .standard:
            nil
        }
    }
}

internal func checkServerErrors(_ document: HTMLDocument) throws {
    if let result = try? DatabaseUnavailableScrapeResult(document, url: nil) {
        throw ServerError.databaseUnavailable(title: result.title, message: result.message)
    } else if let result = try? StandardErrorScrapeResult(document, url: nil) {
        throw ServerError.standard(title: result.title, message: result.message)
    } else if let result = try? BannedScrapeResult(document, url: nil) {
        throw ServerError.banned(reason: result.reason, help: result.help)
    }
}


internal func prepareFormEntries(_ submission: SubmittableForm.PreparedSubmission) -> [Dictionary<String, Any>.Element] {
    return submission.entries.map { ($0.name, $0.value ) }
}


internal func findMessageText(in parsed: ParsedDocument) throws -> String {
    let form = try Form(parsed.document.requiredNode(matchingSelector: "form[name='vbform']"), url: parsed.url)
    guard let message = form.controls.first(where: { $0.name == "message" }) else {
        throw ScrapingError.missingExpectedElement("textarea[name = 'message']")
    }
    return (message.value as NSString).html_stringByUnescapingHTML
}

private func findIgnoreFormkey(in parsed: ParsedDocument) throws -> String {
    return parsed.document.firstNode(matchingSelector: "input[value='ignore']")
        .flatMap { $0.parent?.firstNode(matchingSelector: "input[name = 'formkey']") }
        .map { $0["value"] }
    ?? ""
}
