//  ForumsClient.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation
import HTMLReader
import PromiseKit

/// Sends data to and scrapes data from the Something Awful Forums.
public final class ForumsClient {
    private var urlSession: ForumsURLSession?
    private var backgroundManagedObjectContext: NSManagedObjectContext?
    private var lastModifiedObserver: LastModifiedContextObserver?

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
            urlSession = baseURL.map(ForumsURLSession.init)
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
                .flatMap { context.object(with: $0) }
                .forEach { $0.willAccessValue(forKey: nil) }

            context.mergeChanges(fromContextDidSave: notification)
        }
    }

    private var loginCookie: HTTPCookie? {
        return baseURL
            .flatMap { urlSession?.httpCookieStorage?.cookies(for: $0) }?
            .first { $0.name == "bbuserid" }
    }

    /// Whether or not a valid, logged-in session exists.
    public var isLoggedIn: Bool {
        return loginCookie != nil
    }

    /// When the valid, logged-in session expires.
    public var loginCookieExpiryDate: Date? {
        return loginCookie?.expiresDate
    }

    enum PromiseError: Error {
        case failedTransferToMainContext
        case missingURLSession
        case invalidBaseURL
        case missingDataAndError
        case missingManagedObjectContext
        case unexpectedContentType(String, expected: String)
    }

    private func fetch(
        method: ForumsURLSession.Method,
        urlString: String,
        parameters: [String: Any]?,
        redirectBlock: ForumsURLSession.WillRedirectCallback? = nil)
        -> (promise: ForumsURLSession.PromiseType, cancellable: Cancellable)
    {
        guard let urlSession = urlSession else {
            return (Promise(error: PromiseError.missingURLSession), Operation())
        }

        let tuple = urlSession.fetch(method: method, urlString: urlString, parameters: parameters, redirectBlock: redirectBlock)

        _ = tuple.promise.then { data, response -> Void in
            if !self.isLoggedIn, let block = self.didRemotelyLogOut {
                DispatchQueue.main.async(execute: block)
            }
        }

        return tuple
    }

    // MARK: Forums Session

    public func logIn(username: String, password: String) -> Promise<User> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "login",
            "username": username,
            "password" : password,
            "next": "/member.php?action=getinfo"]

        return fetch(method: .post, urlString: "account.php?json=1", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global(), execute: ProfileScrapeResult.init)
            .then(on: backgroundContext) { scrapeResult, context -> NSManagedObjectID in
                let profile = try scrapeResult.upsert(into: context)
                try context.save()
                return profile.user.objectID
            }
            .then(on: mainContext) { objectID, context in
                guard let user = context.object(with: objectID) as? User else {
                    throw PromiseError.failedTransferToMainContext
                }
                return user
        }
    }

    // MARK: Forums

    public func taxonomizeForums() -> Promise<[Forum]> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        // Seems like only `forumdisplay.php` and `showthread.php` have the `<select>` with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
        return fetch(method: .get, urlString: "forumdisplay.php", parameters: ["forumid": "48"])
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [NSManagedObjectID] in
                let scraper = AwfulForumHierarchyScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }

                guard let forums = scraper.forums else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't find forums"])
                }

                try context.save()

                return forums.map { $0.objectID }
            }
            .then(on: mainContext) { objectIDs, context -> [Forum] in
                return objectIDs.flatMap { context.object(with: $0) as? Forum }
        }
    }

    // MARK: Threads

    /// - Parameter tagged: A thread tag to use for filtering forums, or `nil` for no filtering.
    public func listThreads(in forum: Forum, tagged threadTag: ThreadTag?, page: Int) -> Promise<[AwfulThread]> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        var parameters = [
            "forumid": forum.forumID,
            "perpage": "40",
            "pagenumber": "\(page)"]
        if let threadTagID = threadTag?.threadTagID, !threadTagID.isEmpty {
            parameters["posticon"] = threadTagID
        }

        return fetch(method: .get, urlString: "forumdisplay.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [NSManagedObjectID] in
                let scraper = AwfulThreadListScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }

                guard let threads = scraper.threads as? [AwfulThread] else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't find threads"])
                }

                if
                    page == 1,
                    var threadsToForget = scraper.forum?.threads as? Set<AwfulThread>
                {
                    threadsToForget.subtract(threads)
                    threadsToForget.forEach { $0.threadListPage = 0 }
                }
                threads.forEach { $0.threadListPage = Int32(page) }
                try context.save()

                return threads.map { $0.objectID }
            }
            .then(on: mainContext) { objectIDs, context -> [AwfulThread] in
                return objectIDs.flatMap { context.object(with: $0) as? AwfulThread }
        }
    }

    public func listBookmarkedThreads(page: Int) -> Promise<[AwfulThread]> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "view",
            "perpage": "40",
            "pagenumber": "\(page)"]

        return fetch(method: .get, urlString: "bookmarkthreads.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [NSManagedObjectID] in
                let scraper = AwfulThreadListScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }

                guard let threads = scraper.threads as? [AwfulThread] else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't find threads"])
                }
                threads.forEach { $0.bookmarked = true }

                let threadIDsToIgnore = threads.map { $0.threadID }
                let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
                fetchRequest.predicate = NSPredicate(format: "bookmarked = YES && bookmarkListPage >= %ld && NOT(threadID IN %@)", Int64(page), threadIDsToIgnore)
                let threadsToForget = try context.fetch(fetchRequest)
                threadsToForget.forEach { $0.bookmarkListPage = 0 }
                threads.forEach { $0.bookmarkListPage = Int32(page) }

                try context.save()

                return threads.map { $0.objectID }
            }
            .then(on: mainContext) { objectIDs, context -> [AwfulThread] in
                return objectIDs.flatMap { context.object(with: $0) as? AwfulThread }
        }
    }

    public func setThread(_ thread: AwfulThread, isBookmarked: Bool) -> Promise<Void> {
        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "json": "1",
            "action": isBookmarked ? "add" : "remove",
            "threadid": thread.threadID]

        return fetch(method: .post, urlString: "bookmarkthreads.php", parameters: parameters)
            .promise
            .then(on: mainContext) { response, context in
                thread.bookmarked = isBookmarked
                if isBookmarked, thread.bookmarkListPage <= 0 {
                    thread.bookmarkListPage = 1
                }
                try context.save()
        }
    }

    public func rate(_ thread: AwfulThread, as rating: Int) -> Promise<Void> {
        let parameters = [
            "vote": "\(max(5, min(1, rating)))",
            "threadid": thread.threadID]

        return fetch(method: .post, urlString: "threadrate.php", parameters: parameters)
            .promise.asVoid()
    }

    public func markThreadAsReadUpTo(_ post: Post) -> Promise<Void> {
        guard let threadID = post.thread?.threadID else {
            assertionFailure("post needs a thread ID")
            let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            return Promise(error: error)
        }

        let parameters = [
            "action": "setseen",
            "threadid": threadID,
            "index": "\(post.threadIndex)"]

        return fetch(method: .get, urlString: "showthread.php", parameters: parameters)
            .promise.asVoid()
    }

    public func markUnread(_ thread: AwfulThread) -> Promise<Void> {
        let parameters = [
            "threadid": thread.threadID,
            "action": "resetseen",
            "json": "1"]

        return fetch(method: .post, urlString: "showthread.php", parameters: parameters)
            .promise.asVoid()
    }

    public func listAvailablePostIcons(inForumIdentifiedBy forumID: String) -> Promise<AwfulForm> {
        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "newthread",
            "forumid": forumID]

        return fetch(method: .get, urlString: "newthread.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: mainContext) { document, context -> AwfulForm in
                guard
                    let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm) else
                {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find new thread form"])
                }

                form.scrapeThreadTags(into: context)
                try context.save()

                return form
        }
    }

    public func postThread(in forum: Forum, subject: String, threadTag: ThreadTag?, secondaryTag: ThreadTag?, bbcode: String) -> Promise<AwfulThread> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "newthread",
            "forumid": forum.forumID]

        let formAndParameters = fetch(method: .get, urlString: "newthread.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> (AwfulForm, [String: Any]) in
                guard
                    let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm),
                    let parameters = form.recommendedParameters() as? [String: Any] else
                {
                    let specialMessage = document.firstNode(matchingSelector: "#content center div.standard")
                    if
                        let specialMessage = specialMessage,
                        specialMessage.textContent.contains("accepting")
                    {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                            NSLocalizedDescriptionKey: "You're not allowed to post threads in this forum"])
                    }
                    else {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find new thread form"])
                    }
                }

                form.scrapeThreadTags(into: backgroundContext)
                try backgroundContext.save()

                return (form, parameters)
        }

        let threadTagObjectID = threadTag?.objectID
        let secondaryTagObjectID = secondaryTag?.objectID


        let submitParameters = formAndParameters
            .then(on: backgroundContext) { formAndParameters, context -> [String: Any] in
                let (form, _) = formAndParameters
                var (_, parameters) = formAndParameters
                parameters["subject"] = subject

                if
                    let objectID = threadTagObjectID,
                    let threadTag = context.object(with: objectID) as? ThreadTag,
                    let imageName = threadTag.imageName,
                    let threadTagID = form.threadTagID(withImageName: imageName),
                    let key = form.selectedThreadTagKey
                {
                    parameters[key] = threadTagID
                }

                parameters["message"] = bbcode

                if
                    let objectID = secondaryTagObjectID,
                    let threadTag = context.object(with: objectID) as? ThreadTag,
                    let imageName = threadTag.imageName,
                    let threadTagID = form.secondaryThreadTagID(withImageName: imageName),
                    let key = form.selectedSecondaryThreadTagKey
                {
                    parameters[key] = threadTagID
                }

                parameters.removeValue(forKey: "preview")

                return parameters
        }

        let threadID = submitParameters
            .then { self.fetch(method: .post, urlString: "newthread.php", parameters: $0).promise }
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                guard
                    let link = document.firstNode(matchingSelector: "a[href *= 'showthread']"),
                    let href = link["href"],
                    let components = URLComponents(string: href),
                    let queryItems = components.queryItems,
                    let threadIDPair = queryItems.first(where: { $0.name == "threadid" }),
                    let threadID = threadIDPair.value else
                {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "The new thread could not be located. Maybe it didn't actually get made. Double-check if your thread has appeared, then try again."])
                }

                return threadID
        }

        return threadID
            .then(on: mainContext) { threadID, context -> AwfulThread in
                let key = ThreadKey(threadID: threadID)
                guard let thread = AwfulThread.objectForKey(objectKey: key, inManagedObjectContext: context) as? AwfulThread else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "The new thread could not be saved, but it was probably made. Check the forum you posted it in."])
                }

                return thread
        }
    }

    /// - Returns: The promise of the previewed post's HTML.
    public func previewOriginalPostForThread(in forum: Forum, bbcode: String) -> (Promise<String>, Cancellable) {
        let parameters = [
            "forumid": forum.forumID,
            "action": "postthread",
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Post"]

        let (promise, cancellable) = fetch(method: .post, urlString: "newthread.php", parameters: parameters)
        let html = promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                if let postbody = document.firstNode(matchingSelector: ".postbody") {
                    workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                    return postbody.innerHTML
                }
                else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find previewed original post"])
                }
        }

        return (html, cancellable)
    }

    // MARK: Posts

    /**
     - Parameter writtenBy: A `User` whose posts should be the only ones listed. If `nil`, posts from all authors are listed.
     - Parameter updateLastReadPost: If `true`, the "last read post" marker on the Forums is updated to include the posts loaded on the page (which is probably what you want). If `false`, the next time the user asks for "next unread post" they'll get the same answer again.
     */
    public func listPosts(in thread: AwfulThread, writtenBy author: User?, page: Int, updateLastReadPost: Bool)
        -> (promise: Promise<(posts: [Post], firstUnreadPost: Int?, advertisementHTML: String)>, cancellable: Cancellable)
    {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return (Promise(error: PromiseError.missingManagedObjectContext), Operation())
        }

        var parameters = [
            "threadid": thread.threadID,
            "perpage": "40"]

        switch page {
        case AwfulThreadPage.nextUnread.rawValue:
            parameters["goto"] = "newpost"
        case AwfulThreadPage.last.rawValue:
            parameters["goto"] = "lastpost"
        default:
            parameters["pagenumber"] = "\(page)"
        }

        if !updateLastReadPost {
            parameters["noseen"] = "1"
        }

        if let userID = author?.userID {
            parameters["userid"] = userID
        }

        // SA: We set perpage=40 above to effectively ignore the user's "number of posts per page" setting on the Forums proper. When we get redirected (i.e. goto=newpost or goto=lastpost), the page we're redirected to is appropriate for our hardcoded perpage=40. However, the redirected URL has **no** perpage parameter, so it defaults to the user's setting from the Forums proper. This block maintains our hardcoded perpage value.
        func redirectBlock(task: URLSessionTask, response: HTTPURLResponse, newRequest: URLRequest) -> URLRequest? {
            var components = newRequest.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
            let queryItems = (components?.queryItems ?? [])
                .filter { $0.name != "perpage" }
            components?.queryItems = queryItems
                + [URLQueryItem(name: "perpage", value: "40")]

            var request = newRequest
            request.url = components?.url
            return request
        }

        let (promise, cancellable) = fetch(method: .get, urlString: "showthread.php", parameters: parameters, redirectBlock: redirectBlock)

        let parsed = promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global(), execute: PostsPageScrapeResult.init)

        let posts = parsed
            .then(on: backgroundContext) { scrapeResult, context -> [NSManagedObjectID] in
                let posts = try scrapeResult.upsert(into: context)
                try context.save()
                return posts.map { $0.objectID }
            }
            .then(on: mainContext) { objectIDs, context -> [Post] in
                return objectIDs.flatMap { context.object(with: $0) as? Post }
            }

        let firstUnreadPostIndex = promise
            .then(on: .global()) { data, response -> Int? in
            guard page == AwfulThreadPage.nextUnread.rawValue else { return nil }
            guard let fragment = response.url?.fragment, !fragment.isEmpty else { return nil }

            let scanner = Scanner.awful_scanner(with: fragment)
            guard scanner.scanString("pti", into: nil) else { return nil }

            var scannedInt: Int = 0
            guard scanner.scanInt(&scannedInt), scannedInt != 0 else { return nil }
            return scannedInt
        }

        let altogether = when(fulfilled: posts, firstUnreadPostIndex, parsed)
            .then { posts, firstUnreadPostIndex, scrapeResult in
                return (posts: posts, firstUnreadPost: firstUnreadPostIndex, advertisementHTML: scrapeResult.advertisement)
        }

        return (altogether, cancellable)
    }

    /**
     - Parameter post: An ignored post whose author and innerHTML should be filled.
     */
    public func readIgnoredPost(_ post: Post) -> Promise<Void> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let postContext = post.managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "showpost",
            "postid": post.postID]

        return fetch(method: .get, urlString: "showthread.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> Void in
                let scraper = AwfulPostScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }
                guard scraper.post != nil else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find post"])
                }

                try context.save()
            }
            .then(on: postContext) { (_, context) -> Void in
                context.refresh(post, mergeChanges: true)
        }
    }

    public enum ReplyLocation {
        case lastPostInThread
        case post(Post)
    }

    public func reply(to thread: AwfulThread, bbcode: String) -> Promise<ReplyLocation> {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "newreply",
            "threadid": thread.threadID]
        let wasThreadClosed = thread.closed
        let formParameters = fetch(method: .get, urlString: "newreply.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [String: Any] in
                guard
                    let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm),
                    var parameters = form.recommendedParameters() as? [String: Any] else
                {
                    let description = wasThreadClosed
                        ? "Could not reply; the thread may be closed."
                        : "Could not reply; failed to find the form."
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: description])
                }

                parameters["message"] = bbcode
                parameters.removeValue(forKey: "preview")
                return parameters
        }

        let postID = formParameters
            .then { self.fetch(method: .post, urlString: "newreply.php", parameters: $0).promise }
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String? in
                let link = document.firstNode(matchingSelector: "a[href *= 'goto=post']")
                    ?? document.firstNode(matchingSelector: "a[href *= 'goto=lastpost']")
                let queryItems = link
                    .flatMap { $0["href"] }
                    .flatMap { URLComponents(string: $0) }
                    .flatMap { $0.queryItems }
                if
                    let goto = queryItems?.first(where: { $0.name == "goto" }),
                    goto.value == "post",
                    let postID = queryItems?.first(where: { $0.name == "postid" })?.value
                {
                    return postID
                }
                else {
                    return nil
                }
        }

        return postID
            .then(on: mainContext) { postID, context -> ReplyLocation in
                if let postID = postID {
                    let key = PostKey(postID: postID)
                    guard let post = Post.objectForKey(objectKey: key, inManagedObjectContext: context) as? Post else {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not save new post. It might've worked anyway"])
                    }
                    return .post(post)
                }
                else {
                    return .lastPostInThread
                }
        }
    }

    public func previewReply(to thread: AwfulThread, bbcode: String) -> (promise: Promise<String>, cancellable: Cancellable) {
        let parameters = [
            "action": "postreply",
            "threadid": thread.threadID,
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Reply"]

        let (promise, cancellable) = fetch(method: .post, urlString: "newreply.php", parameters: parameters)

        let parsed = promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find previewed post"])
                }

                workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                return postbody.innerHTML
        }

        return (promise: parsed, cancellable: cancellable)
    }

    public func findBBcodeContents(of post: Post) -> Promise<String> {
        let parameters = [
            "action": "editpost",
            "postid": post.postID]

        return fetch(method: .get, urlString: "editpost.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                guard let message = form?.allParameters?["message"] else {
                    if form != nil {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find post contents in edit post form"])
                    }
                    else {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find edit post form"])
                    }
                }

                return message
        }
    }

    public func quoteBBcodeContents(of post: Post) -> Promise<String> {
        let parameters = [
            "action": "newreply",
            "postid": post.postID]

        return fetch(method: .get, urlString: "newreply.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                guard
                    let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm),
                    let bbcode = form.allParameters?["message"] else
                {
                    if
                        let specialMessage = document.firstNode(matchingSelector: "#content center div.standard"),
                        specialMessage.textContent.contains("permission")
                    {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                            NSLocalizedDescriptionKey: "You're not allowed to post in this thread"])
                    }
                    else {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to quote post; could not find form"])
                    }
                }

                return bbcode
        }
    }

    public func edit(_ post: Post, bbcode: String) -> Promise<Void> {
        let parameters = [
            "action": "editpost",
            "postid": post.postID]

        return fetch(method: .get, urlString: "editpost.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> [String: Any] in
                guard
                    let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm),
                    var parameters = form.recommendedParameters() as? [String: Any],
                    parameters["postid"] != nil else
                {
                    if
                        let specialMessage = document.firstNode(matchingSelector: "#content center div.standard"),
                        specialMessage.textContent.contains("permission")
                    {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                            NSLocalizedDescriptionKey: "You're not allowed to edit posts in this thread"])
                    }
                    else {
                        throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to edit post; could not find form"])
                    }
                }

                parameters["message"] = bbcode
                parameters.removeValue(forKey: "preview")
                return parameters
            }
            .then { self.fetch(method: .post, urlString: "editpost.php", parameters: $0).promise }
            .asVoid()
    }

    /**
     - Parameter postID: The post's ID. Specified directly in case no such post exists, which would make for a useless `Post`.
     - Returns: The promise of a post (with its `thread` set) and the page containing the post (may be `AwfulThreadPage.last`).
     */
    public func locatePost(id postID: String) -> Promise<(post: Post, page: Int)> {
        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that redirect, then parse out the info we need.
        let redirectURL = Promise<URL>.pending()

        func redirectBlock(task: URLSessionTask, response: HTTPURLResponse, newRequest: URLRequest) -> URLRequest? {
            if
                let url = newRequest.url,
                url.lastPathComponent == "showthread.php",
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let queryItems = components.queryItems,
                queryItems.first(where: { $0.name == "goto" }) != nil
            {
                return newRequest
            }

            task.cancel()

            guard let url = newRequest.url else {
                redirectURL.reject(
                NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                    NSLocalizedDescriptionKey: "The post could not be found (missing URL)"]))
                return URLRequest(url: URL(string: "http:")!) // can't return nil for some reason?
            }

            redirectURL.fulfill(url)
            return nil
        }

        let parameters = [
            "goto": "post",
            "postid": postID]

        fetch(method: .get, urlString: "showthread.php", parameters: parameters, redirectBlock: redirectBlock)
            .promise
            .then { data, response -> Void in
                // Once we have the redirect we want, we cancel the operation. So if this "success" callback gets called, we've actually failed.
                redirectURL.reject(
                    NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "The post could not be found"]))
            }
            .catch { error -> Void in
                // This catch excludes cancellation, so we've legitimately failed.
                redirectURL.reject(error)
        }

        return redirectURL.promise
            .then(on: .global()) { url -> (threadID: String, page: Int) in
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                    let threadID = components.queryItems?.first(where: { $0.name == "threadid" })?.value,
                    !threadID.isEmpty,
                    let rawPagenumber = components.queryItems?.first(where: { $0.name == "pagenumber" })?.value,
                    let pagenumber = Int(rawPagenumber) else
                {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "The thread ID or page number could not be found"])
                }

                return (threadID: threadID, page: pagenumber)
            }
            .then(on: mainContext) { parsed, context -> (post: Post, page: Int) in
                let (threadID: threadID, page: page) = parsed
                let postKey = PostKey(postID: postID)
                let threadKey = ThreadKey(threadID: threadID)
                guard
                    let post = Post.objectForKey(objectKey: postKey, inManagedObjectContext: mainContext) as? Post,
                    let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: mainContext) as? AwfulThread else
                {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't make the post or thread"])
                }

                post.thread = thread
                try context.save()

                return (post: post, page: page)
        }
    }

    public func previewEdit(to post: Post, bbcode: String) -> (promise: Promise<String>, cancellable: Cancellable) {
        let parameters = [
            "action": "updatepost",
            "postid": post.postID,
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Post"]

        let (promise, cancellable) = fetch(method: .post, urlString: "editpost.php", parameters: parameters)

        let parsed = promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                guard let postbody = document.firstNode(matchingSelector: ".postbody") else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find previewed post"])
                }

                workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                return postbody.innerHTML
        }

        return (promise: parsed, cancellable: cancellable)
    }

    /**
     - Parameter reason: A further explanation of what's wrong with the post. Truncated to 60 characters.
     */
    public func report(_ post: Post, reason: String) -> Promise<Void> {
        let parameters = [
            "action": "submit",
            "postid": post.postID,
            "comments": String(reason.characters.prefix(60))]

        return fetch(method: .post, urlString: "modalert.php", parameters: parameters)
            .promise.asVoid()
            .recover { error -> Void in
                print("error reporting post \(post.postID): \(error)")
        }
    }

    // MARK: Users

    private func profile(parameters: [String: Any]) -> Promise<NSManagedObjectID> {
        guard let backgroundContext = backgroundManagedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        return fetch(method: .get, urlString: "member.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global(), execute: ProfileScrapeResult.init)
            .then(on: backgroundContext) { scrapeResult, context -> NSManagedObjectID in
                let profile = try scrapeResult.upsert(into: context)
                try context.save()
                return profile.objectID
            }
    }

    public func profileLoggedInUser() -> Promise<User> {
        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        return profile(parameters: ["action": "getinfo"])
            .then(on: mainContext) { objectID, context -> User in
                guard let profile = context.object(with: objectID) as? Profile else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not save profile"])
                }

                return profile.user
        }
    }

    /**
     - Parameter id: The user's ID. Specified directly in case no such user exists, which would make for a useless `User`.
     - Parameter username: The user's username. If userID is not given, username must be given.
     */
    public func profileUser(id userID: String?, username: String?) -> Promise<Profile> {
        assert(userID != nil || username != nil)

        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        var parameters = ["action": "getinfo"]
        if let userID = userID, !userID.isEmpty {
            parameters["userid"] = userID
        }
        else if let username = username {
            parameters["username"] = username
        }

        return profile(parameters: parameters)
            .then(on: mainContext) { objectID, context -> Profile in
                guard let profile = context.object(with: objectID) as? Profile else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not save profile"])
                }

                return profile
        }
    }

    private func lepersColony(parameters: [String: Any]) -> Promise<[Punishment]> {
        guard let mainContext = managedObjectContext else {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        return fetch(method: .get, urlString: "banlist.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: mainContext) { document, context -> [Punishment] in
                let scraper = LepersColonyPageScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }
                guard let punishments = scraper.punishments else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find punishments"])
                }

                try context.save()
                return punishments
        }
    }

    public func listPunishments(of user: User?, page: Int) -> Promise<[Punishment]> {
        guard let user = user else {
            return lepersColony(parameters: ["pagenumber": "\(page)"])
        }

        let userID: Promise<String>
        if !user.userID.isEmpty {
            userID = Promise(value: user.userID)
        }
        else {
            guard let username = user.username else {
                assertionFailure("need user ID or username")
                return lepersColony(parameters: ["pagenumber": "\(page)"])
            }

            userID = profileUser(id: nil, username: username)
                .then { $0.user.userID }
        }

        return userID
            .then { userID -> Promise<[Punishment]> in
                let parameters = [
                    "pagenumber": "\(page)",
                    "userid": userID]
                return self.lepersColony(parameters: parameters)
        }
    }

    // MARK: Private Messages

    public func countUnreadPrivateMessagesInInbox() -> Promise<Int> {
        return fetch(method: .get, urlString: "private.php", parameters: nil)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> Int in
                return try UnreadPrivateMessageCountScrapeResult(document).unreadPrivateMessageCount
        }
    }

    public func listPrivateMessagesInInbox() -> Promise<[PrivateMessage]> {
        guard
            let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        return fetch(method: .get, urlString: "private.php", parameters: nil)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [NSManagedObjectID] in
                let scraper = PrivateMessageFolderScraper.scrape(document, into: context)
                if let error = scraper.error {
                    throw error
                }
                guard let messages = scraper.messages else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find messages"])
                }

                try context.save()

                return messages.map { $0.objectID }
            }
            .then(on: mainContext) { (objectIDs, context) -> [PrivateMessage] in
                return objectIDs.flatMap { context.object(with: $0) as? PrivateMessage }
        }
    }

    public func deletePrivateMessage(_ message: PrivateMessage) -> Promise<Void> {
        let parameters = [
            "action": "dodelete",
            "privatemessageid": message.messageID,
            "delete": "yes"]

        return fetch(method: .post, urlString: "private.php", parameters: parameters)
            .promise.asVoid()
    }

    public func readPrivateMessage(identifiedBy messageKey: PrivateMessageKey) -> Promise<PrivateMessage> {
        guard
            let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = [
            "action": "show",
            "privatemessageid": messageKey.messageID]

        return fetch(method: .get, urlString: "private.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global(), execute: PrivateMessageScrapeResult.init)
            .then(on: backgroundContext) { scrapeResult, context -> NSManagedObjectID in
                let message = try scrapeResult.upsert(into: context)
                try context.save()
                return message.objectID
            }
            .then(on: mainContext) { objectID, context -> PrivateMessage in
                guard let privateMessage = context.object(with: objectID) as? PrivateMessage else {
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not save message"])
                }
                return privateMessage
        }
    }

    public func quoteBBcodeContents(of message: PrivateMessage) -> Promise<String> {
        let parameters = [
            "action": "newmessage",
            "privatemessageid": message.messageID]

        return fetch(method: .get, urlString: "private.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: .global()) { document -> String in
                let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                guard let message = form?.allParameters?["message"] else {
                    let missingBit = form == nil ? "form" : "text box"
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Failed quoting private message; could not find \(missingBit)"])
                }
                return message
        }
    }

    public func listAvailablePrivateMessageThreadTags() -> Promise<[ThreadTag]> {
        guard
            let mainContext = managedObjectContext,
            let backgroundContext = backgroundManagedObjectContext else
        {
            return Promise(error: PromiseError.missingManagedObjectContext)
        }

        let parameters = ["action": "newmessage"]

        return fetch(method: .get, urlString: "private.php", parameters: parameters)
            .promise
            .then(on: .global(), execute: parseHTML)
            .then(on: backgroundContext) { document, context -> [NSManagedObjectID] in
                let htmlForm = document.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                form?.scrapeThreadTags(into: context)
                guard let threadTags = form?.threadTags else {
                    let description: String
                    if form == nil {
                        description = "Could not find new private message form"
                    }
                    else {
                        description = "Failed scraping thread tags from new private message form"
                    }
                    throw NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: description])
                }

                try context.save()

                return threadTags.map { $0.objectID }
            }
            .then(on: mainContext) { managedObjectIDs, context -> [ThreadTag] in
                return managedObjectIDs.flatMap { context.object(with: $0) as? ThreadTag }
        }
    }

    /**
     - Parameters:
        - to: The intended recipient's username. (Requiring a `User` would be unhelpful as the username is typed in and may not actually exist.)
        - regarding: Should be `nil` if `forwarding` parameter is non-`nil`.
        - forwarding: Should be `nil` if `regarding` is non-`nil`.
     */
    public func sendPrivateMessage(to username: String, subject: String, threadTag: ThreadTag?, bbcode: String, regarding regardingMessage: PrivateMessage?, forwarding forwardedMessage: PrivateMessage?) -> Promise<Void> {
        var parameters = [
            "touser": username,
            "title": subject,
            "iconid": threadTag?.threadTagID ?? "0",
            "message": bbcode,
            "action": "dosend",
            "forward": forwardedMessage?.messageID == nil ? "" : "true",
            "savecopy": "yes",
            "submit": "Send Message"]

        if let prevmessageID = (regardingMessage ?? forwardedMessage)?.messageID {
            parameters["prevmessageid"] = prevmessageID
        }

        return fetch(method: .post, urlString: "private.php", parameters: parameters)
            .promise.asVoid()
    }
}


/// A (typically network) operation that can be cancelled.
public protocol Cancellable: class {

    /// Idempotent.
    func cancel()
}

extension Operation: Cancellable {}
extension URLSessionTask: Cancellable {}


private func parseHTML(data: Data, response: URLResponse) throws -> HTMLDocument {
    let contentType: String? = {
        guard let response = response as? HTTPURLResponse else { return nil }
        return response.allHeaderFields["Content-Type"] as? String
    }()
    let document = HTMLDocument(data: data, contentTypeHeader: contentType)
    try checkServerErrors(document)
    return document
}

private func parseJSONDict(data: Data, response: URLResponse) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dict = json as? [String: Any] else {
        throw ForumsClient.PromiseError.unexpectedContentType("\(type(of: json))", expected: "Dictionary<String, Any>")
    }
    return dict
}


private func workAroundAnnoyingImageBBcodeTagNotMatching(in postbody: HTMLElement) {
    for img in postbody.nodes(matchingSelector: "img[src^='http://awful-image']") {
        if let src = img["src"] {
            let suffix = src.characters.dropFirst("http://".characters.count)
            img["src"] = String(suffix)
        }
    }
}


extension Promise {
    fileprivate func then<U>(on context: NSManagedObjectContext, execute body: @escaping (T, _ context: NSManagedObjectContext) throws -> U) -> Promise<U> {
        return then(on: .global()) { value -> Promise<U> in
            return Promise<U> { fulfill, reject in
                context.perform {
                    do {
                        try fulfill(body(value, context))
                    }
                    catch {
                        reject(error)
                    }
                }
            }
        }
    }
}


enum ServerError: LocalizedError {
    case databaseUnavailable(title: String, message: String)
    case standard(title: String, message: String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable(title: _, message: let message),
             .standard(title: _, message: let message):
            return message
        }
    }
}

private func checkServerErrors(_ document: HTMLDocument) throws {
    if let result = try? DatabaseUnavailableScrapeResult(document) {
        throw ServerError.databaseUnavailable(title: result.title, message: result.message)
    }
    else if let result = try? StandardErrorScrapeResult(document) {
        throw ServerError.standard(title: result.title, message: result.message)
    }
}
