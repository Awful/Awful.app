//
//  ForumsClient.swift
//  Awful
//
//  Created by Nolan Waite on 2017-04-22.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import AFNetworking
import CoreData
import Foundation
import HTMLReader

/// Sends data to and scrapes data from the Something Awful Forums.
public final class ForumsClient {
    private var httpManager: HTTPRequestOperationManager?
    private var backgroundManagedObjectContext: NSManagedObjectContext?
    private var lastModifiedObserver: LastModifiedContextObserver?

    /// A block to call when the login session is destroyed. Not called when logging out from Awful.
    public var didRemotelyLogOut: (() -> Void)?

    /// Convenient singleton.
    public static let shared = ForumsClient()
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(networkOperationDidStart), name: .AFNetworkingOperationDidFinish, object: nil)
    }
    
    deinit {
        httpManager?.operationQueue.cancelAllOperations()
    }

    @objc private func networkOperationDidStart(_ notification: Notification) {
        guard
            isLoggedIn,
            let op = notification.object as? AFURLConnectionOperation,
            let url = op.request.url,
            let baseURL = baseURL,
            url.absoluteString.hasPrefix(baseURL.absoluteString)
            else { return }

        NotificationCenter.default.addObserver(self, selector: #selector(networkOperationDidFinish), name: .AFNetworkingOperationDidFinish, object: op)
    }

    @objc private func networkOperationDidFinish(_ notification: Notification) {
        guard let op = notification.object as? AFHTTPRequestOperation else { return }

        if op.error == nil && !isLoggedIn {
            didRemotelyLogOut?()
        }
    }

    /**
     The Forums endpoint for the client. Typically https://forums.somethingawful.com

     Setting a new baseURL cancels all in-flight requests.
     */
    public var baseURL: URL? {
        get {
            return httpManager?.baseURL
        }
        set {
            guard newValue != httpManager?.baseURL else { return }
            
            httpManager?.operationQueue.cancelAllOperations()
            httpManager = HTTPRequestOperationManager(baseURL: newValue)
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

    /// Whether or not the Forums endpoint appears reachable.
    public var isReachable: Bool {
        return httpManager?.reachabilityManager.isReachable ?? false
    }

    private var loginCookie: HTTPCookie? {
        return baseURL
            .flatMap { HTTPCookieStorage.shared.cookies(for: $0) }?
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

    // MARK: Session

    /**
     - Parameter completion: A block to call after logging in, which takes as parameters: an `Error` on failure, or `nil` on success; and a `User` on success or `nil` on failure.
     */
    public func logIn(username: String, password: String, completion: @escaping (_ error: Error?, _ user: User?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = [
            "action": "login",
            "username": username,
            "password" : password,
            "next": "/member.php?action=getinfo"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { ProfileScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.profile != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectID = scraper?.profile?.user.objectID
                DispatchQueue.main.async {
                    let user = objectID.flatMap { mainContext.object(with: $0) as? User }
                    completion(error, user)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            var error = error
            if op?.response?.statusCode == 401 {
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: "Invalid username or password",
                    NSUnderlyingErrorKey: error]
                error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.invalidUsernameOrPassword, userInfo: userInfo)
            }
            completion(error, nil)
        }

        return httpManager?.post("account.php?json=1", parameters: parameters, success: success, failure: failure)
    }

    // MARK: - Forums

    /**
     - Parameter completion: A block to call after finding the forum hierarchy which takes as parameters: an `Error` on failure or `nil` on success; and an array of `Forum`s on success or `nil` on failure.
     */
    public func taxonomizeForums(completion: @escaping (_ error: Error?, _ forums: [Forum]?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = ["forumid": "48"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulForumHierarchyScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.forums != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectIDs = (scraper?.forums ?? []).map { $0.objectID }
                DispatchQueue.main.async {
                    let forums = objectIDs.flatMap { mainContext.object(with: $0) as? Forum }
                    completion(error, forums)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
        return httpManager?.get("forumdisplay.php", parameters: parameters, success: success, failure: failure)
    }

    // MARK: - Threads

    /**
     - Parameter threadTag: A thread tag to use for filtering forums, or `nil` for no filtering.
     - Parameter callback: A block to call after listing the threads which takes two parameters: an `Error` on failure or `nil` on success; and an array of `AwfulThread`s on success or `nil` on failure.
     */
    public func listThreads(in forum: Forum, taggedWith threadTag: ThreadTag?, on page: Int, completion: @escaping (_ error: Error?, _ threads: [AwfulThread]?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        var parameters = [
            "forumid": forum.forumID,
            "perpage": "40",
            "pagenumber": "\(page)"]
        if let threadTagID = threadTag?.threadTagID, !threadTagID.isEmpty {
            parameters["posticon"] = threadTagID
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulThreadListScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if let threads = scraper?.threads as? [AwfulThread], error == nil {
                    if page == 1, var threadsToForget = scraper?.forum?.threads as? Set<AwfulThread> {
                        threadsToForget.subtract(threads)
                        threadsToForget.forEach { $0.threadListPage = 0 }
                    }
                    threads.forEach { $0.threadListPage = Int32(page) }
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectIDs = (scraper?.threads as? [AwfulThread] ?? []).map { $0.objectID }
                DispatchQueue.main.async {
                    let threads = objectIDs.flatMap { mainContext.object(with: $0) as? AwfulThread }
                    completion(error, threads)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("forumdisplay.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after listing the threads which takes two parameters: an `Error` on failure or `nil` on success; and an array of `AwfulThread`s on success or `nil` on failure.
     */
    public func listBookmarkedThreads(on page: Int, completion: @escaping (_ error: Error?, _ threads: [AwfulThread]?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = [
            "action": "view",
            "perpage": "40",
            "pagenumber": "\(page)"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulThreadListScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if let threads = scraper?.threads as? [AwfulThread], error == nil {
                    threads.forEach { $0.bookmarked = true }
                    let threadIDsToIgnore = threads.map { $0.threadID }
                    let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())
                    fetchRequest.predicate = NSPredicate(format: "bookmarked = YES && bookmarkListPage >= %ld && NOT(threadID IN %@)", Int64(page), threadIDsToIgnore)
                    do {
                        let threadsToForget = try backgroundContext.fetch(fetchRequest)
                        threadsToForget.forEach { $0.bookmarkListPage = 0 }
                    }
                    catch let fetchError {
                        error = fetchError
                    }
                    threads.forEach { $0.bookmarkListPage = Int32(page) }
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectIDs = (scraper?.threads as? [AwfulThread] ?? []).map { $0.objectID }
                DispatchQueue.main.async {
                    let threads = objectIDs.flatMap { mainContext.object(with: $0) as? AwfulThread }
                    completion(error, threads)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("bookmarkthreads.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after (un)bookmarking the thread, which takes an `Error` as a parameter on failure, or `nil` on success.
     */
    public func setThread(_ thread: AwfulThread, isBookmarked: Bool, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        let parameters = [
            "json": "1",
            "action": isBookmarked ? "add" : "remove",
            "threadid": thread.threadID]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            thread.bookmarked = isBookmarked
            if isBookmarked, thread.bookmarkListPage <= 0 {
                thread.bookmarkListPage = 1
            }
            let error: Error?
            do {
                try thread.managedObjectContext?.save()
                error = nil
            }
            catch let saveError {
                error = saveError
            }
            completion(error)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("bookmarkthreads.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after rating the thread, which takes as a parameter an `Error` on failure or `nil` on success.
     */
    public func rate(_ thread: AwfulThread, as rating: Int, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        let parameters = [
            "vote": "\(max(5, min(1, rating)))",
            "threadid": thread.threadID]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("threadrate.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after marking the thread read, which takes as a parameter an `Error` on failure or `nil` on success.
     */
    public func markThreadAsReadUpTo(_ post: Post, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        guard let threadID = post.thread?.threadID else {
            assertionFailure("post needs a thread ID")
            let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            completion(error)
            return Operation()
        }
        let parameters = [
            "action": "setseen",
            "threadid": threadID,
            "index": "\(post.threadIndex)"]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.get("showthread.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after marking the thread unread, which takes as a parameter an `Error` object on failure or `nil` on success.
     */
    public func markUnread(_ thread: AwfulThread, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        let parameters = [
            "threadid": thread.threadID,
            "action": "resetseen",
            "json": "1"]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("showthread.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     List post icons usable for a new thread in a forum.
     
     - Parameter forumID: Which forum to list icons for.
     - Parameter completion: A block to call after listing post icons, which takes as parameters: an `Error` on failure, or `nil` on success; an `AwfulForm` with thread tags and secondary thread tags on success, or `nil` on failure.
     */
    public func listAvailablePostIcons(inForumIdentifiedBy forumID: String, completion: @escaping (_ error: Error?, _ form: AwfulForm?) -> Void) -> Cancellable? {
        guard let mainContext = managedObjectContext else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = [
            "action": "newthread",
            "forumid": forumID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            DispatchQueue.global(qos: .userInitiated).async {
                let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                mainContext.perform {
                    let error: Error?
                    if let form = form {
                        do {
                            form.scrapeThreadTags(into: mainContext)
                            try mainContext.save()
                            error = nil
                        }
                        catch let saveError {
                            error = saveError
                        }
                    }
                    else {
                        error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find new thread form"])
                    }
                    completion(error, form)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("newthread.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after posting the thread, which takes as parameters: an `Error` on failure or `nil` on success; and the new `AwfulThread` on success, or `nil` on failure.
     */
    public func postThread(in forum: Forum, subject: String, threadTag: ThreadTag?, secondaryTag: ThreadTag?, bbcode: String, completion: @escaping (_ error: Error?, _ thread: AwfulThread?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext,
            let httpManager = httpManager else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        let parameters = [
            "action": "newthread",
            "forumid": forum.forumID]

        let threadTagObjectID = threadTag?.objectID
        let secondaryTagObjectID = secondaryTag?.objectID
        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                guard var parameters = form?.recommendedParameters() as? [String: Any] else {
                    let error: Error
                    let specialMessage = document?.firstNode(matchingSelector: "#content center div.standard")
                    if
                        let specialMessage = specialMessage,
                        specialMessage.textContent.contains("accepting")
                    {
                        error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                            NSLocalizedDescriptionKey: "You're not allowed to post threads in this forum"])
                    }
                    else {
                        error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find new thread form"])
                    }
                    DispatchQueue.main.async {
                        completion(error, nil)
                    }
                    return
                }

                form?.scrapeThreadTags(into: backgroundContext)

                parameters["subject"] = subject

                if
                    let objectID = threadTagObjectID,
                    let threadTag = backgroundContext.object(with: objectID) as? ThreadTag,
                    let imageName = threadTag.imageName,
                    let threadTagID = form?.threadTagID(withImageName: imageName),
                    let key = form?.selectedThreadTagKey
                {
                    parameters[key] = threadTagID
                }

                parameters["message"] = bbcode

                if
                    let objectID = secondaryTagObjectID,
                    let threadTag = backgroundContext.object(with: objectID) as? ThreadTag,
                    let imageName = threadTag.imageName,
                    let threadTagID = form?.secondaryThreadTagID(withImageName: imageName),
                    let key = form?.selectedSecondaryThreadTagKey
                {
                    parameters[key] = threadTagID
                }

                parameters.removeValue(forKey: "preview")

                let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
                    let document = document as? HTMLDocument
                    let link = document?.firstNode(matchingSelector: "a[href *= 'showthread']")
                    let threadID = (link?["href"])
                        .flatMap { URLComponents(string: $0) }
                        .flatMap { $0.queryItems }?
                        .first { $0.name == "threadid" }?
                        .value
                    let thread: AwfulThread?
                    let error: Error?
                    if let threadID = threadID {
                        thread = AwfulThread.objectForKey(objectKey: ThreadKey(threadID: threadID), inManagedObjectContext: mainContext) as? AwfulThread
                        error = nil
                    }
                    else {
                        thread = nil
                        error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                            NSLocalizedDescriptionKey: "The new thread could not be located. Maybe it didn't actually get made. Double-check if your thread has appeared, then try again."])
                    }
                    completion(error, thread)
                }

                httpManager.post("newthread.php", parameters: parameters, success: success, failure: failure)
            }
        }

        return httpManager.get("newthread.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after rendering the preview, which returns nothing and takes as parameters: an `Error` object on failure or `nil` on success; and the rendered post's HTML on success or `nil` on failure.
     */
    public func previewOriginalPostForThread(in forum: Forum, bbcode: String, completion: @escaping (_ error: Error?, _ postHTML: String?) -> Void) -> Cancellable? {
        let parameters = [
            "forumid": forum.forumID,
            "action": "postthread",
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Post"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            let postbody = document?.firstNode(matchingSelector: ".postbody")
            if let postbody = postbody {
                workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                completion(nil, postbody.innerHTML)
            }
            else {
                let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find previewed original post"])
                completion(error, nil)
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.post("newthread.php", parameters: parameters, success: success, failure: failure)
    }

    // MARK: - Posts

    /**
     - Parameter writtenBy: A `User` whose posts should be the only ones listed. If `nil`, posts from all authors are listed.
     - Parameter updateLastReadPost: If `true`, the "last read post" marker on the Forums is updated to include the posts loaded on the page (which is probably what you want). If `false`, the next time the user asks for "next unread post" they'll get the same answer again.
     - Parameter completion: A block to call after listing posts, which takes as parameters: an `Error` on failure, or `nil` on success; an array of `AwfulPost`s on success, or `nil` on failure; the index of the first unread post in the posts array on success; and the banner ad HTML on success.
     */
    public func listPosts(in thread: AwfulThread, writtenBy author: User?, page: Int, updateLastReadPost: Bool, completion: @escaping (_ error: Error?, _ posts: [Post]?, _ firstUnreadPost: Int, _ advertisementHTML: String?) -> Void) -> Cancellable? {
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

        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext,
            let httpManager = httpManager else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil, NSNotFound, nil)
            return nil
        }

        var error: NSError?
        let url = URL(string: "showthread.php", relativeTo: httpManager.baseURL)
        let request = httpManager.requestSerializer.request(withMethod: "GET", urlString: url?.absoluteString ?? "", parameters: parameters, error: &error)
        // Checking the error is bad form, but the request serializer interface claims (seemingly incorrectly) to return a nonnull instance, so I'm not sure how else to check for a failure here.
        if error != nil {
            completion(error, nil, NSNotFound, nil)
            return nil
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulPostsPageScraper.scrape($0, into: backgroundContext) }
                let error: Error?
                if scraper?.posts != nil {
                    do {
                        try backgroundContext.save()
                        error = nil
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                else {
                    error = nil
                }

                let firstUnreadPostIndex: Int? = {
                    guard page == AwfulThreadPage.nextUnread.rawValue else { return nil }
                    guard let fragment = op.response?.url?.fragment, !fragment.isEmpty else { return nil }

                    let scanner = Scanner.awful_scanner(with: fragment)
                    guard scanner.scanString("pti", into: nil) else { return nil }

                    var scannedInt: Int = 0
                    guard scanner.scanInt(&scannedInt), scannedInt != 0 else { return nil }
                    return scannedInt
                }()

                let objectIDs = (scraper?.posts ?? []).map { $0.objectID }
                DispatchQueue.main.async {
                    // The posts page scraper may have updated the passed-in thread, so we should make sure the passed-in thread is up-to-date. And although the AwfulForumsClient API is assumed to be called from the main thread, we cannot assume the passed-in thread's context is the same as our main thread context.
                    thread.managedObjectContext?.refresh(thread, mergeChanges: true)

                    let posts = objectIDs.flatMap { mainContext.object(with: $0) as? Post }
                    completion(error, posts, firstUnreadPostIndex ?? NSNotFound, scraper?.advertisementHTML)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation, error: Error) -> Void in
            completion(error, nil, NSNotFound, nil)
        }

        let op = httpManager.httpRequestOperation(with: request as URLRequest, success: success, failure: failure)

        // SA: We set perpage=40 above to effectively ignore the user's "number of posts per page" setting on the Forums proper. When we get redirected (i.e. goto=newpost or goto=lastpost), the page we're redirected to is appropriate for our hardcoded perpage=40. However, the redirected URL has **no** perpage parameter, so it defaults to the user's setting from the Forums proper. This block maintains our hardcoded perpage value.
        op.setRedirectResponseBlock { (connection, request, redirectResponse) -> URLRequest in
            var components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
            let queryItems = (components?.queryItems ?? [])
                .filter { $0.name != "perpage" }
            components?.queryItems = queryItems
                + [URLQueryItem(name: "perpage", value: "40")]
            var request = request
            request.url = components?.url
            return request
        }

        httpManager.operationQueue.addOperation(op)
        return op
    }

    /**
     - Parameter post: An ignored post whose author and innerHTML should be filled.
     - Parameter completion: A block to call after reading the post, which takes a single parameter: an `Error` on failure, or `nil` on success.
     */
    public func readIgnoredPost(_ post: Post, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        guard let backgroundContext = backgroundManagedObjectContext else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
            return nil
        }

        let parameters = [
            "action": "showpost",
            "postid": post.postID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulPostScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.post != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }

                    post.managedObjectContext?.performAndWait {
                        post.managedObjectContext?.refresh(post, mergeChanges: true)
                    }
                }
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.get("showthread.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after sending the reply, which takes as parameters: an `Error` on failure, or `nil` on success; and the newly-created `Post` on success, or `nil` on failure.
     */
    public func reply(to thread: AwfulThread, bbcode: String, completion: @escaping (_ error: Error?, _ post: Post?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext,
            let httpManager = httpManager else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        let parameters = [
            "action": "newreply",
            "threadid": thread.threadID]

        let wasThreadClosed = thread.closed
        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                guard
                    let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']"),
                    let form = AwfulForm(element: htmlForm),
                    var parameters = form.recommendedParameters() as? [String: Any] else
                {
                    let description = wasThreadClosed
                        ? "Could not reply; the thread may be closed."
                        : "Could not reply; failed to find the form."
                    let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: description])
                    DispatchQueue.main.async {
                        completion(error, nil)
                    }
                    return
                }

                parameters["message"] = bbcode
                parameters.removeValue(forKey: "preview")

                let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
                    let document = document as? HTMLDocument
                    let link = document?.firstNode(matchingSelector: "a[href *= 'goto=post']")
                        ?? document?.firstNode(matchingSelector: "a[href *= 'goto=lastpost']")
                    let components = link
                        .flatMap { $0["href"] }
                        .flatMap { URLComponents(string: $0) }
                    let postKey: PostKey? = {
                        guard let queryItems = components?.queryItems else { return nil }
                        let goto = queryItems.first { $0.name == "goto" }
                        guard goto?.value == "post" else { return nil }
                        let postID = queryItems.first { $0.name == "postid" }?.value
                        return postID.map { PostKey(postID: $0) }
                    }()
                    let post = postKey.flatMap { Post.objectForKey(objectKey: $0, inManagedObjectContext: mainContext) as? Post }
                    completion(nil, post)
                }

                httpManager.post("newreply.php", parameters: parameters, success: success, failure: failure)
            }
        }

        return httpManager.get("newreply.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after rendering the preview, which returns nothing and takes as parameters: an `Error` on failure, or `nil` on success; and the rendered post's HTML on success or `nil` on failure.
     */
    public func previewReply(to thread: AwfulThread, bbcode: String, completion: @escaping (_ error: Error?, _ postHTML: String?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "postreply",
            "threadid": thread.threadID,
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Reply"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            if let postbody = document?.firstNode(matchingSelector: ".postbody") {
                workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                completion(nil, postbody.innerHTML)
            }
            else {
                let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find previewed post"])
                completion(error, nil)
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.post("newreply.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after finding the text of the post, which takes as parameters: an `Error` on failure, or `nil` on success; and the BBcode text of the post on success, or `nil` on failure.
     */
    public func findBBcodeContents(of post: Post, completion: @escaping (_ error: Error?, _ text: String?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "editpost",
            "postid": post.postID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
            let form = htmlForm.flatMap { AwfulForm(element: $0) }
            let message = form?.allParameters?["message"]
            let error: Error?
            if message == nil {
                if form != nil {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find post contents in edit post form"])
                }
                else {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find edit post form"])
                }
            }
            else {
                error = nil
            }
            completion(error, message)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("editpost.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after finding the quoted text of the post, which takes as parameters: an `Error` on failure, or `nil` on success; and the BBcode quoted text of the post on success, or `nil` on failure.
     */
    public func quoteBBcodeContents(of post: Post, completion: @escaping (_ error: Error?, _ quotedText: String?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "newreply",
            "postid": post.postID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
            let form = htmlForm.flatMap { AwfulForm(element: $0) }
            let bbcode = form?.allParameters?["message"]
            let error: Error?
            if bbcode == nil {
                if
                    let specialMessage = document?.firstNode(matchingSelector: "#content center div.standard"),
                    specialMessage.textContent.contains("permission")
                {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                        NSLocalizedDescriptionKey: "You're not allowed to post in this thread"])
                }
                else {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to quote post; could not find form"])
                }
            }
            else {
                error = nil
            }
            completion(error, bbcode)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("newreply.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     A block to call after editing the post, which takes as a parameter an `Error` on failure or `nil` on success.
     */
    public func edit(_ post: Post, bbcode: String, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        guard let httpManager = httpManager else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
            return nil
        }

        let parameters = [
            "action": "editpost",
            "postid": post.postID]

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
            let form = htmlForm.flatMap { AwfulForm(element: $0) }
            guard
                var parameters = form?.recommendedParameters() as? [String: Any],
                parameters["postid"] != nil else
            {
                let error: Error?
                if
                    let specialMessage = document?.firstNode(matchingSelector: "#content center div.standard"),
                    specialMessage.textContent.contains("permission")
                {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.forbidden, userInfo: [
                        NSLocalizedDescriptionKey: "You're not allowed to edit posts in this thread"])
                }
                else {
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to edit post; could not find form"])
                }
                completion(error)
                return
            }

            parameters["message"] = bbcode
            parameters.removeValue(forKey: "preview")

            let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
                completion(nil)
            }

            httpManager.post("editpost.php", parameters: parameters, success: success, failure: failure)
        }

        return httpManager.get("editpost.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after rendering the preview, which returns nothing and takes as parameters: an `Error` on failure or `nil` on success; and the rendered post's HTML on success or `nil` on failure.
     */
    public func previewEdit(to post: Post, bbcode: String, completion: @escaping (_ error: Error?, _ postHTML: String?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "updatepost",
            "postid": post.postID,
            "message": bbcode,
            "parseurl": "yes",
            "preview": "Preview Post"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            if let postbody = document?.firstNode(matchingSelector: ".postbody") {
                workAroundAnnoyingImageBBcodeTagNotMatching(in: postbody)
                completion(nil, postbody.innerHTML)
            }
            else {
                let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find previewd post"])
                completion(error, nil)
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.post("editpost.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter postID: The post's ID. Specified directly in case no such post exists, which would make for a useless `Post`.
     - Parameter completion: A block to call after locating the post, which takes as parameters: an `Error` object on failure or `nil` on success; a `Post` on success or `nil` on failure; and the page containing the post (may be `AwfulThreadPage.last`).
     */
    public func locatePost(id postID: String, completion: @escaping (_ error: Error?, _ post: Post?, _ page: Int) -> Void) -> Cancellable? {
        guard
            let mainContext = managedObjectContext,
            let httpManager = httpManager else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil, 0)
            return nil
        }

        // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that redirect, then parse out the info we need.
        var didSucceed = false

        let parameters = [
            "goto": "post",
            "postid": postID]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            // Once we have the redirect we want, we cancel the operation. So if this "success" callback gets called, we've actually failed.
            let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                NSLocalizedDescriptionKey: "The post could not be found"])
            completion(error, nil, 0)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            if !didSucceed {
                completion(error, nil, 0)
            }
        }

        let url = URL(string: "showthread.php", relativeTo: httpManager.baseURL)
        var error: NSError?
        let request = url.map { httpManager.requestSerializer.request(withMethod: "GET", urlString: $0.absoluteString, parameters: parameters, error: &error) }
        let op = request.map { httpManager.httpRequestOperation(with: $0 as URLRequest, success: success, failure: failure) }

        op?.setRedirectResponseBlock({ [weak op] (connection, redirectRequest, response) -> URLRequest in
            didSucceed = true
            op?.cancel()

            let components = redirectRequest.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
            let rawThreadID = components?.queryItems?.first(where: { $0.name == "threadid" })?.value
            guard
                let threadID = rawThreadID,
                !threadID.isEmpty,
                let rawPagenumber = components?.queryItems?.first(where: { $0.name == "pagenumber" })?.value,
                let pagenumber = Int(rawPagenumber) else
            {
                let missingInfo = rawThreadID == nil ? "thread ID" : "page number"
                let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                    NSLocalizedDescriptionKey: "The \(missingInfo) could not be found"])
                DispatchQueue.main.async {
                    completion(error, nil, 0)
                }
                return URLRequest(url: URL(string: "http:")!) // can't return nil for some reason?
            }

            mainContext.perform {
                let postKey = PostKey(postID: postID)
                let post = Post.objectForKey(objectKey: postKey, inManagedObjectContext: mainContext) as? Post
                let threadKey = ThreadKey(threadID: threadID)
                let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: mainContext) as? AwfulThread
                post?.thread = thread
                let error: Error?
                do {
                    try mainContext.save()
                    error = nil
                }
                catch let saveError {
                    error = saveError
                }
                DispatchQueue.main.async {
                    completion(error, post, pagenumber)
                }
            }

            return URLRequest(url: URL(string: "http:")!) // can't return nil for some reason?
        })

        if let op = op {
            httpManager.operationQueue.addOperation(op)
        }
        return op
    }

    /**
     - Parameter reason: A further explanation of what's wrong with the post. Truncated to 60 characters.
     */
    public func report(_ post: Post, reason: String, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "submit",
            "postid": post.postID,
            "comments": String(reason.characters.prefix(60))]

        let success = { (op: AFHTTPRequestOperation, response: Any) -> Void in
            // Error checking is intentionally lax here. Let plat non-havers spin their wheels.
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("modalert.php", parameters: parameters, success: success, failure: failure)
    }

    // MARK: - People

    /**
     - Parameter completion: A block to call after learning user info, which takes as parameters: an `Error` on failure or `nil` on success; and a `User` for the logged-in user on success, or `nil` on failure.
     */
    public func profileLoggedInUser(completion: @escaping (_ error: Error?, _ user: User?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = ["action": "getinfo"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { ProfileScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.profile?.user != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectID = scraper?.profile?.user.objectID
                DispatchQueue.main.async {
                    let user = objectID.flatMap { mainContext.object(with: $0) as? User }
                    completion(error, user)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("member.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter id: The user's ID. Specified directly in case no such user exists, which would make for a useless `User`.
     - Parameter username: The user's username. If userID is not given, username must be given.
     - Parameter completion: A block to call after learning of the user's info, which takes as parameters: an `Error` on failure or `nil` on success; and a `Profile` on success or `nil` on failure.
     */
    public func profileUser(id userID: String?, username: String?, completion: @escaping (_ error: Error?, _ profile: Profile?) -> Void) -> Cancellable? {
        assert(userID != nil || username != nil)

        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        var parameters = ["action": "getinfo"]
        if let userID = userID, !userID.isEmpty {
            parameters["userid"] = userID
        }
        else if let username = username {
            parameters["username"] = username
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { ProfileScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.profile != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectID = scraper?.profile?.objectID
                DispatchQueue.main.async {
                    let profile = objectID.flatMap { mainContext.object(with: $0) as? Profile }
                    completion(error, profile)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("member.php", parameters: parameters, success: success, failure: failure)
    }

    // MARK: - Leper's Colony

    /**
     - Parameter completion: A block to call after listing bans and probations, which takes as parameters: an `Error` on failure or `nil` on success; and an array of `Punishment`s on success, or `nil` on failure.
     */
    public func listPunishments(of user: User?, page: Int, completion: @escaping (_ error: Error?, _ punishments: [Punishment]?) -> Void) -> Cancellable? {
        guard let httpManager = httpManager, let mainContext = managedObjectContext else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        func doIt() -> Cancellable? {
            var parameters: [String: Any] = ["pagenumber": "\(page)"]
            if let userID = user?.userID {
                parameters["userid"] = userID
            }

            let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
                let document = document as? HTMLDocument
                mainContext.perform {
                    let scraper = document.map { LepersColonyPageScraper.scrape($0, into: mainContext) }
                    var error = scraper?.error
                    if scraper?.punishments != nil {
                        do {
                            try mainContext.save()
                        }
                        catch let saveError {
                            error = saveError
                        }
                    }
                    completion(error, scraper?.punishments)
                }
            }

            let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
                completion(error, nil)
            }

            return httpManager.get("banlist.php", parameters: parameters, success: success, failure: failure)
        }

        if
            let user = user,
            let username = user.username,
            !username.isEmpty,
            user.userID.isEmpty
        {
            return profileUser(id: nil, username: username, completion: { (error, profile) in
                if let error = error {
                    return completion(error, nil)
                }
                _ = doIt()
            })
        }
        else {
            return doIt()
        }
    }

    // MARK: - Private Messages

    /**
     - Parameter completion: A block to call after counting the unread messages in the logged-in user's PM inbox, which takes as parameters: an `Error` on failure, or `nil` on success; and the number of unread messages on success, or `nil` on failure.
     */
    public func countUnreadPrivateMessagesInInbox(completion: @escaping (_ error: Error?, _ unreadMessageCount: Int?) -> Void) -> Cancellable? {
        guard let backgroundContext = backgroundManagedObjectContext else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { AwfulUnreadPrivateMessageCountScraper.scrape($0, into: backgroundContext) }
                DispatchQueue.main.async {
                    completion(scraper?.error, scraper?.unreadPrivateMessageCount)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("private.php", parameters: nil, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after listing the logged-in user's PM inbox, which takes as parameters: an `Error` on failure, or `nil` on success; and an array of `PrivateMessage`s on success, or `nil` on failure.
     */
    public func listPrivateMessagesInInbox(completion: @escaping (_ error: Error?, _ messages: [PrivateMessage]?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { PrivateMessageFolderScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.messages != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectIDs = (scraper?.messages ?? []).map { $0.objectID }
                mainContext.perform {
                    let messages = objectIDs.flatMap { mainContext.object(with: $0) as? PrivateMessage }
                    completion(error, messages)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("private.php", parameters: nil, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after deleting the message, which takes as a parameter an `Error` on failure, or `nil` on success.
     */
    public func deletePrivateMessage(_ message: PrivateMessage, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
        let parameters = [
            "action": "dodelete",
            "privatemessageid": message.messageID,
            "delete": "yes"]

        let success = { (op: AFHTTPRequestOperation, responseObject: Any) -> Void in
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("private.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after reading the message, which takes as parameters: an `Error` on failure, or `nil` on success; and the read `PrivateMessage` on success, or `nil` on failure.
     */
    public func readPrivateMessage(identifiedBy messageKey: PrivateMessageKey, completion: @escaping (_ error: Error?, _ message: PrivateMessage?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = [
            "action": "show",
            "privatemessageid": messageKey.messageID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let scraper = document.map { PrivateMessageScraper.scrape($0, into: backgroundContext) }
                var error = scraper?.error
                if scraper?.privateMessage != nil {
                    do {
                        try backgroundContext.save()
                    }
                    catch let saveError {
                        error = saveError
                    }
                }
                let objectID = scraper?.privateMessage?.objectID
                mainContext.perform {
                    let message = objectID.flatMap { mainContext.object(with: $0) as? PrivateMessage }
                    completion(error, message)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("private.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after quoting the message, which takes as parameters: an `Error` on failure or `nil` on success; and the quoted BBcode contents on success or `nil` on failure.
     */
    public func quoteBBcodeContents(of message: PrivateMessage, completion: @escaping (_ error: Error?, _ bbcode: String?) -> Void) -> Cancellable? {
        guard let backgroundContext = backgroundManagedObjectContext else {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = [
            "action": "newmessage",
            "privatemessageid": message.messageID]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                let message = form?.allParameters?["message"]
                let error: Error?
                if message == nil {
                    let missingBit = form == nil ? "form" : "text box"
                    error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: "Failed quoting private message; could not find \(missingBit)"])
                }
                else {
                    error = nil
                }
                DispatchQueue.main.async {
                    completion(error, message)
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("private.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter completion: A block to call after listing thread tags, which takes as parameters: an `Error` on failure, or `nil` on success; and an array of `ThreadTag`s on success, or `nil` on failure.
     */
    public func listAvailablePrivateMessageThreadTags(completion: @escaping (_ error: Error?, _ threadTags: [ThreadTag]?) -> Void) -> Cancellable? {
        guard
            let backgroundContext = backgroundManagedObjectContext,
            let mainContext = managedObjectContext else
        {
            assertionFailure("need client setup")
            completion(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil), nil)
            return nil
        }

        let parameters = ["action": "newmessage"]

        let success = { (op: AFHTTPRequestOperation, document: Any) -> Void in
            let document = document as? HTMLDocument
            backgroundContext.perform {
                let htmlForm = document?.firstNode(matchingSelector: "form[name='vbform']")
                let form = htmlForm.flatMap { AwfulForm(element: $0) }
                form?.scrapeThreadTags(into: backgroundContext)
                if let threadTags = form?.threadTags {
                    do {
                        try backgroundContext.save()
                    }
                    catch {
                        return DispatchQueue.main.async { completion(error, nil) }
                    }

                    let objectIDs = threadTags.map { $0.objectID }
                    mainContext.perform {
                        let threadTags = objectIDs.flatMap { mainContext.object(with: $0) as? ThreadTag }
                        completion(nil, threadTags)
                    }
                }
                else {
                    let description: String
                    if form == nil {
                        description = "Could not find new private message form"
                    }
                    else {
                        description = "Failed scraping thread tags from new private message form"
                    }
                    let error = NSError(domain: AwfulCoreError.domain, code: AwfulCoreError.parseError, userInfo: [
                        NSLocalizedDescriptionKey: description])
                    DispatchQueue.main.async { completion(error, nil) }
                }
            }
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error, nil)
        }

        return httpManager?.get("private.php", parameters: parameters, success: success, failure: failure)
    }

    /**
     - Parameter to: The intended recipient's username. (Requiring a `User` would be unhelpful as the username is typed in and may not actually exist.)
     - Parameter regarding: Should be `nil` if `forwarding` parameter is non-`nil`.
     - Parameter forwarding: Should be `nil` if `regarding` is non-`nil`.
     - Parameter completion: A block to call after sending the message, which takes as a parameter an `Error` on failure, or `nil` on success.
     */
    public func sendPrivateMessage(to username: String, subject: String, threadTag: ThreadTag?, bbcode: String, regarding regardingMessage: PrivateMessage?, forwarding forwardedMessage: PrivateMessage?, completion: @escaping (_ error: Error?) -> Void) -> Cancellable? {
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

        let success = { (op: AFHTTPRequestOperation, responseObject: Any) -> Void in
            completion(nil)
        }

        let failure = { (op: AFHTTPRequestOperation?, error: Error) -> Void in
            completion(error)
        }

        return httpManager?.post("private.php", parameters: parameters, success: success, failure: failure)
    }
}

/// A (typically network) operation that can be cancelled.
public protocol Cancellable: class {

    /// Idempotent.
    func cancel()
}

extension Operation: Cancellable {}

private func workAroundAnnoyingImageBBcodeTagNotMatching(in postbody: HTMLElement) {
    for img in postbody.nodes(matchingSelector: "img[src^='http://awful-image']") {
        if let src = img["src"] {
            let suffix = src.characters.dropFirst("http://".characters.count)
            img["src"] = String(suffix)
        }
    }
}
