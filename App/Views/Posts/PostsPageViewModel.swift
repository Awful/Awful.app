//  PostsPageViewModel.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import Foundation
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageViewModel")

/// Global coordinator to manage WebView restoration state across view recreation
@MainActor
final class PostsWebViewRestorationCoordinator {
    static let shared = PostsWebViewRestorationCoordinator()
    
    private var restoredThreads: Set<String> = []
    
    private init() {}
    
    /// Mark that WebView content has been restored for a specific thread
    func markContentRestored(for threadID: String) {
        logger.info("🔧 PostsWebViewRestorationCoordinator: Marking content as restored for thread \(threadID)")
        restoredThreads.insert(threadID)
    }
    
    /// Check if WebView content was restored for a specific thread
    func wasContentRestored(for threadID: String) -> Bool {
        let wasRestored = restoredThreads.contains(threadID)
        logger.info("🔧 PostsWebViewRestorationCoordinator: Checking thread \(threadID) - wasRestored: \(wasRestored)")
        return wasRestored
    }
    
    /// Clear restoration state for a specific thread (call when navigation completes successfully)
    func clearRestorationState(for threadID: String) {
        logger.info("🔧 PostsWebViewRestorationCoordinator: Clearing restoration state for thread \(threadID)")
        restoredThreads.remove(threadID)
    }
    
    /// Clear all restoration state (call on app startup)
    func clearAllRestorationState() {
        logger.info("🔧 PostsWebViewRestorationCoordinator: Clearing all restoration state")
        restoredThreads.removeAll()
    }
}

@MainActor
final class PostsPageViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var currentPage: ThreadPage?
    @Published var numberOfPages: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var jumpToPostID: String? {
        didSet {
            print("🎯 PostsPageViewModel: jumpToPostID changed from '\(oldValue ?? "nil")' to '\(jumpToPostID ?? "nil")'")
        }
    }
    @Published var scrollToFraction: CGFloat?
    @Published var firstUnreadPost: Int?
    
    // MARK: - Computed Properties
    var isLastPage: Bool {
        guard let currentPage = currentPage else { return false }
        switch currentPage {
        case .last:
            return true
        case .specific(let n):
            return n == numberOfPages
        case .nextUnread:
            return false
        }
    }
    
    // MARK: - Dependencies
    let thread: AwfulThread
    let author: User?
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    
    // MARK: - Private State
    private var networkOperation: Task<(posts: [Post], firstUnreadPost: Int?, advertisementHTML: String, pageCount: Int), Error>?
    private(set) var advertisementHTML: String?
    private var cachedPageModel: (posts: [Post], firstUnreadPost: Int?, advertisementHTML: String, pageCount: Int)?
    private var cancellables: Set<AnyCancellable> = []
    private var hasAttemptedInitialScroll = false
    private var isReRenderingAfterMarkAsRead = false
    private var flagRequest: Task<Void, Error>?
    
    // MARK: - WebView Coordination
    private let viewModelInstanceID = UUID().uuidString.prefix(8)
    
    /// Check if WebView content was restored using global coordinator
    var webViewContentWasRestored: Bool {
        PostsWebViewRestorationCoordinator.shared.wasContentRestored(for: self.thread.threadID)
    }
    
    /// Called by WebView restoration to indicate content has been restored and navigation should not trigger fresh page loads
    func markWebViewContentAsRestored() {
        logger.info("🔧 PostsPageViewModel[\(self.viewModelInstanceID)]: WebView content marked as restored for thread \(self.thread.threadID)")
        PostsWebViewRestorationCoordinator.shared.markContentRestored(for: self.thread.threadID)
    }
    
    /// Debug property to track ViewModel instances
    var debugInstanceID: String { String(viewModelInstanceID) }
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil) {
        self.thread = thread
        self.author = author
        self.numberOfPages = Int(author != nil ? thread.filteredNumberOfPagesForAuthor(author!) : thread.numberOfPages)
    }
    
    deinit {
        networkOperation?.cancel()
        flagRequest?.cancel()
    }
    
    // MARK: - Page Loading
    func loadInitialPage() {
        logger.info("🚀 loadInitialPage: thread='\(self.thread.title ?? "Unknown")', beenSeen=\(self.thread.beenSeen), anyUnreadPosts=\(self.thread.anyUnreadPosts)")
        
        // Determine initial page based on thread state
        let initialPage: ThreadPage
        
        if thread.beenSeen && thread.anyUnreadPosts {
            initialPage = .nextUnread
            logger.info("📖 Decision: Loading nextUnread page (thread seen with unread posts)")
        } else if thread.beenSeen {
            // Thread has been seen but no unread posts - go to last page
            initialPage = .last
            logger.info("📖 Decision: Loading LAST page (thread seen, no unread posts) ⭐️")
        } else {
            // Thread hasn't been seen - go to first page
            initialPage = .specific(1)
            logger.info("📖 Decision: Loading first page (thread not seen)")
        }
        
        logger.info("🎯 About to call loadPage with: \(String(describing: initialPage))")
        // Always update read position - server should track page views
        loadPage(initialPage, updatingCache: true, updatingLastReadPost: true)
    }
    
    func loadPage(_ newPage: ThreadPage, updatingCache: Bool = true, updatingLastReadPost: Bool = true) {
        logger.info("📄 loadPage[\(self.viewModelInstanceID)]: \(String(describing: newPage)) for thread '\(self.thread.title ?? "Unknown")', updatingCache=\(updatingCache), updatingLastReadPost=\(updatingLastReadPost)")
        
        // Check if WebView content was already restored
        if webViewContentWasRestored {
            logger.info("🔧 PostsPageViewModel[\(self.viewModelInstanceID)]: Skipping page load - WebView content was already restored")
            PostsWebViewRestorationCoordinator.shared.clearRestorationState(for: self.thread.threadID) // Reset flag for next time
            return
        }
        
        // Cancel any existing operation
        if let existingOperation = networkOperation {
            logger.info("🚫 Cancelling existing network operation")
            existingOperation.cancel()
        }
        
        // Update state
        currentPage = newPage
        hasAttemptedInitialScroll = false
        isReRenderingAfterMarkAsRead = false
        // Don't clear jumpToPostID if we have one set - it's needed for post navigation
        logger.debug("🎯 loadPage: jumpToPostID before potential clear: \(self.jumpToPostID ?? "nil")")
        if jumpToPostID == nil {
            scrollToFraction = nil
        }
        logger.debug("🎯 loadPage: jumpToPostID after state update: \(self.jumpToPostID ?? "nil")")
        
        if !updatingCache {
            logger.info("Rendering posts without updating cache")
            return
        }
        
        // Set loading state
        isLoading = true
        errorMessage = nil
        
        // Determine first unread post handling
        if case .specific(let pageNumber) = newPage, pageNumber > 1, pageNumber == numberOfPages {
            firstUnreadPost = nil
        } else if case .nextUnread = newPage {
            firstUnreadPost = nil
        } else {
            if thread.beenSeen && thread.anyUnreadPosts {
                // Keep existing firstUnreadPost or let server determine it
            } else {
                firstUnreadPost = 0
            }
        }
        
        // Start network operation
        networkOperation = Task {
            logger.info("🌐 Starting network operation to fetch posts for page \(String(describing: newPage))")
            let startTime = Date()
            
            let result = try await ForumsClient.shared.listPosts(
                in: thread,
                writtenBy: author,
                page: newPage,
                updateLastReadPost: updatingLastReadPost
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Network operation completed in \(String(format: "%.2f", duration))s, fetched \(result.posts.count) posts")
            
            // Cache the result
            self.cachedPageModel = result
            
            return result
        }
        
        // Handle network operation completion
        Task {
            do {
                let (newPosts, firstUnread, adHTML, pageCount) = try await networkOperation!.value
                logger.info("Network operation completed with \(newPosts.count) posts")
                
                await MainActor.run {
                    self.advertisementHTML = adHTML
                    self.posts = newPosts
                    self.firstUnreadPost = firstUnread
                    self.numberOfPages = pageCount
                    self.isLoading = false
                    
                    // Update thread page count if needed
                    if pageCount != Int(self.thread.numberOfPages) {
                        self.thread.numberOfPages = Int32(pageCount)
                    }
                    
                    // Update page state if we loaded nextUnread or last page
                    if let firstPost = newPosts.first, self.currentPage == .nextUnread || self.currentPage == .last {
                        let actualPage = firstPost.page
                        if actualPage > 0 {
                            logger.info("Updating page from \(String(describing: self.currentPage)) to .specific(\(actualPage))")
                            self.currentPage = .specific(actualPage)
                            
                            // Notify coordinator to update navigation state immediately
                            NotificationCenter.default.post(
                                name: Notification.Name("ThreadPageDidChange"),
                                object: nil,
                                userInfo: [
                                    "threadID": self.thread.threadID,
                                    "newPage": ThreadPage.specific(actualPage),
                                    "author": self.author as Any
                                ]
                            )
                        }
                    }
                    
                    // Save context
                    let context = self.thread.managedObjectContext!
                    
                    // Update logged-in user info
                    if let userID = self.loggedInUserID {
                        let user = User.objectForKey(objectKey: UserKey(userID: userID, username: nil), in: context)
                        user.customTitleHTML = newPosts.first(where: { $0.author?.userID == userID })?.author?.customTitleHTML
                    }
                    
                    // Track new authors
                    let allAuthors = Set(newPosts.compactMap { $0.author })
                    let knownAuthorIDs = Set(allAuthors.map { $0.userID })
                    _ = User.tombstones(for: knownAuthorIDs, in: context)
                    
                    do {
                        try context.save()
                    } catch {
                        logger.error("Failed to save context after loading posts: \(error)")
                    }
                    
                    // Handle initial scrolling
                    self.handleInitialScrolling()
                }
            } catch {
                if error is CancellationError {
                    logger.info("🚫 Network operation was cancelled (CancellationError)")
                    return
                } else if let urlError = error as? URLError, urlError.code == .cancelled {
                    logger.info("🚫 Network operation was cancelled (URLError.cancelled)")
                    return
                } else if let urlError = error as? URLError, urlError.code == .timedOut {
                    logger.error("⏰ Network operation timed out")
                } else if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    logger.error("📶 No internet connection")
                } else {
                    logger.error("❌ Failed to load posts: \(error)")
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    logger.info("💾 Error state set: \(error.localizedDescription)")
                }
            }
            
            networkOperation = nil
            logger.debug("🔚 Network operation task completed and cleaned up")
        }
    }
    
    // MARK: - Page Navigation
    func goToPreviousPage() {
        guard case .specific(let pageNumber) = currentPage, pageNumber > 1 else { return }
        loadPage(.specific(pageNumber - 1))
    }
    
    func goToNextPage() {
        print("🔄 PostsPageViewModel: goToNextPage() called")
        guard case .specific(let pageNumber) = currentPage, pageNumber < numberOfPages else { 
            print("🔄 PostsPageViewModel: goToNextPage guard failed - currentPage=\(String(describing: currentPage)), numberOfPages=\(numberOfPages)")
            return 
        }
        // Clear any existing scroll position and jump to post ID to ensure we start at the top
        jumpToPostID = nil
        // Note: Don't set scrollToFraction here - let the SwiftUIPostsPageView handle scroll to top
        print("🔄 goToNextPage: Cleared jumpToPostID, loading page \(pageNumber + 1)")
        loadPage(.specific(pageNumber + 1))
    }
    
    func goToLastPost() {
        loadPage(.last)
    }
    
    func scrollToEnd() {
        scrollToFraction = 1.0
    }
    
    // MARK: - Refresh
    func refresh() {
        guard let page = currentPage else { 
            logger.warning("⚠️ Cannot refresh: no current page set")
            return 
        }
        logger.info("🔄 Refreshing current page: \(String(describing: page))")
        loadPage(page, updatingCache: true, updatingLastReadPost: true)
    }
    
    func refreshWithRetry(maxAttempts: Int = 3) {
        guard let page = currentPage else {
            logger.warning("⚠️ Cannot refresh with retry: no current page set")
            return
        }
        
        Task {
            var attempt = 1
            while attempt <= maxAttempts {
                logger.info("🔄 Refresh attempt \(attempt)/\(maxAttempts) for page: \(String(describing: page))")
                
                do {
                    loadPage(page, updatingCache: true, updatingLastReadPost: true)
                    
                    // Wait for loading to complete
                    while isLoading {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    }
                    
                    if self.errorMessage == nil {
                        logger.info("✅ Refresh succeeded on attempt \(attempt)")
                        return
                    } else {
                        logger.warning("⚠️ Refresh failed on attempt \(attempt): \(self.errorMessage ?? "Unknown error")")
                    }
                } catch {
                    logger.error("❌ Refresh attempt \(attempt) failed: \(error)")
                }
                
                attempt += 1
                if attempt <= maxAttempts {
                    let delay = TimeInterval(attempt * attempt) // Exponential backoff: 4s, 9s
                    logger.info("⏳ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            
            logger.error("❌ All refresh attempts failed")
        }
    }
    
    func refreshCurrentPage() async {
        guard let page = currentPage else { return }
        
        await withCheckedContinuation { continuation in
            loadPage(page, updatingCache: true, updatingLastReadPost: true)
            
            // Wait for loading to complete
            let cancellable = $isLoading
                .filter { !$0 }
                .first()
                .sink { _ in
                    continuation.resume()
                }
            
            // Store cancellable to prevent deallocation
            cancellables.insert(cancellable)
        }
    }
    
    func forceContentRerender() {
        // Force re-render with existing posts when webview content is lost
        logger.info("🔄 Forcing content re-render with existing posts")
        
        // If we have cached posts, trigger a state update to force re-render
        if !self.posts.isEmpty {
            logger.info("🔄 Re-rendering with \(self.posts.count) existing posts")
            let currentPosts = self.posts
            self.posts = [] // Clear temporarily
            DispatchQueue.main.async {
                self.posts = currentPosts // Restore to trigger re-render
            }
        } else if let cachedModel = cachedPageModel {
            // Use cached data if available
            logger.info("🔄 Re-rendering with cached page model")
            self.posts = cachedModel.posts
            self.numberOfPages = cachedModel.pageCount
            self.firstUnreadPost = cachedModel.firstUnreadPost
            self.advertisementHTML = cachedModel.advertisementHTML
        } else {
            // Last resort - refresh from network
            logger.info("🔄 No cached content available, refreshing from network")
            refresh()
        }
    }
    
    // MARK: - Scrolling
    private func isOnLastPage() -> Bool {
        guard let currentPage = currentPage else { return false }
        switch currentPage {
        case .last:
            return true
        case .specific(let pageNumber):
            return pageNumber == numberOfPages
        case .nextUnread:
            return false
        }
    }
    
    private func handleInitialScrolling() {
        logger.info("🚀 handleInitialScrolling called - hasAttemptedInitialScroll: \(self.hasAttemptedInitialScroll)")
        guard !hasAttemptedInitialScroll else { return }
        hasAttemptedInitialScroll = true
        
        logger.info("🔍 Initial scroll conditions - currentPage: \(String(describing: self.currentPage)), posts.count: \(self.posts.count), firstUnreadPost: \(String(describing: self.firstUnreadPost))")
        
        // Skip scrolling if re-rendering after mark as read
        if isReRenderingAfterMarkAsRead {
            logger.info("🔄 Skipping initial scrolling - re-rendering after mark as read")
            isReRenderingAfterMarkAsRead = false
            return
        }
        
        // Priority 1: First unread post
        if let serverFirstUnreadIndex = firstUnreadPost {
            logger.info("📖 Priority 1: Found firstUnreadPost at index \(serverFirstUnreadIndex)")
            let clientFirstUnreadIndex = posts.firstIndex(where: { !$0.beenSeen })
            
            let actualIndex: Int
            if let clientIndex = clientFirstUnreadIndex {
                if clientIndex != serverFirstUnreadIndex {
                    logger.warning("⚠️ Server firstUnreadPost (\(serverFirstUnreadIndex)) differs from client calculation (\(clientIndex))")
                    logger.info("🔧 Using client-side calculation for more accurate positioning")
                    actualIndex = clientIndex
                } else {
                    logger.info("✅ Server and client agree on first unseen post index: \(serverFirstUnreadIndex)")
                    actualIndex = clientIndex
                }
            } else {
                logger.info("📍 No client unseen posts found, using server index: \(serverFirstUnreadIndex)")
                actualIndex = serverFirstUnreadIndex
            }
            
            if actualIndex < posts.count {
                let postID = posts[actualIndex].postID
                logger.info("🎯 Scrolling to first unread post at index \(actualIndex): \(postID)")
                jumpToPostID = postID
                
                // Verify scroll position with detailed logging
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // Allow time for scroll to complete
                    await verifyScrollPosition(targetPostID: postID)
                }
            }
        } else if !posts.isEmpty && isOnLastPage() {
            // Priority 2: When on last page with no unread posts, scroll to the last post (not bottom)
            // This handles both .last pages and .specific pages that are the actual last page
            let lastPostIndex = posts.count - 1
            let lastPostID = posts[lastPostIndex].postID
            logger.info("🎯 Priority 2: On last page (\(String(describing: self.currentPage))) with no unread posts, scrolling to last post at index \(lastPostIndex): \(lastPostID)")
            jumpToPostID = lastPostID
            
            // Verify scroll position with detailed logging
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // Allow time for scroll to complete
                await verifyScrollPosition(targetPostID: lastPostID)
            }
        } else {
            logger.info("ℹ️ Priority 3: No special scrolling required - staying at top. Reasons: currentPage=\(String(describing: self.currentPage)), posts.isEmpty=\(self.posts.isEmpty), firstUnreadPost=\(String(describing: self.firstUnreadPost))")
        }
    }
    
    /// Verifies that the scroll position is correct and logs the result
    @MainActor
    private func verifyScrollPosition(targetPostID: String) async {
        logger.info("🎯 Scroll verification for post ID: \(targetPostID)")
        
        // Debug: Log post seen status around the target
        if let targetIndex = posts.firstIndex(where: { $0.postID == targetPostID }) {
            logger.info("📊 Post seen status analysis around target index \(targetIndex):")
            
            let startIndex = max(0, targetIndex - 2)
            let endIndex = min(posts.count - 1, targetIndex + 2)
            
            for i in startIndex...endIndex {
                let post = posts[i]
                let indicator = i == targetIndex ? "👉" : "  "
                let seenStatus = post.beenSeen ? "SEEN" : "UNSEEN"
                logger.info("\(indicator) Post \(i): \(seenStatus) - ID: \(post.postID)")
            }
            
            // Find the actual first unseen post based on our data
            if let actualFirstUnseenIndex = posts.firstIndex(where: { !$0.beenSeen }) {
                if actualFirstUnseenIndex != targetIndex {
                    logger.warning("⚠️ Server firstUnreadPost (\(targetIndex)) differs from client calculation (\(actualFirstUnseenIndex))")
                    logger.info("🔧 Consider using client-side calculation for more accurate positioning")
                } else {
                    logger.info("✅ Server and client agree on first unseen post index: \(targetIndex)")
                }
            } else {
                logger.info("📋 All posts appear to be seen")
            }
        } else {
            logger.error("❌ Could not find target post ID \(targetPostID) in posts array")
        }
    }
    
    // MARK: - Post Actions
    func replyToPost(_ post: Post? = nil, completion: @escaping (ReplyWorkspace) -> Void) {
        let workspace = ReplyWorkspace(thread: thread)
        completion(workspace)
    }
    
    func quotePost(_ post: Post, completion: @escaping (ReplyWorkspace) -> Void) {
        Task {
            do {
                let workspace = ReplyWorkspace(thread: thread)
                try await workspace.quotePost(post)
                completion(workspace)
            } catch {
                logger.error("Failed to quote post: \(error)")
            }
        }
    }
    
    func editPost(_ post: Post, completion: @escaping (ReplyWorkspace) -> Void) {
        Task {
            do {
                let bbcode = try await ForumsClient.shared.findBBcodeContents(of: post)
                let workspace = ReplyWorkspace(post: post, bbcode: bbcode)
                completion(workspace)
            } catch {
                logger.error("Failed to edit post: \(error)")
            }
        }
    }
    
    func markAsReadUpTo(_ post: Post) {
        guard let currentPostIndex = posts.firstIndex(of: post) else {
            logger.error("Could not find post \(post.postID) in posts array")
            Toast.show(title: "Error: Could not find post", icon: Toast.Icon.error)
            return
        }
        
        let shouldProceed: Bool
        if let firstUnreadPost = firstUnreadPost {
            shouldProceed = currentPostIndex >= firstUnreadPost
        } else {
            shouldProceed = true
        }
        
        guard shouldProceed else {
            Toast.show(title: "Post already marked as read", icon: Toast.Icon.info)
            return
        }
        
        Task {
            do {
                try await ForumsClient.shared.markThreadAsSeenUpTo(post)
                
                if post.threadIndex >= thread.totalReplies {
                    // Reload page if at end of thread
                    loadPage(currentPage!, updatingCache: true, updatingLastReadPost: true)
                } else {
                    // Update local state
                    self.firstUnreadPost = currentPostIndex + 1
                    
                    if thread.seenPosts < Int32(post.threadIndex) {
                        thread.seenPosts = Int32(post.threadIndex)
                        
                        let context = thread.managedObjectContext!
                        do {
                            try context.save()
                        } catch {
                            logger.error("Failed to save thread context: \(error)")
                        }
                    }
                    
                    isReRenderingAfterMarkAsRead = true
                }
                
                NotificationCenter.default.post(name: .threadBookmarkDidChange, object: thread)
                Toast.show(title: "Marked as read", icon: Toast.Icon.checkmark)
            } catch {
                logger.error("Could not mark thread as read: \(error)")
                Toast.show(title: "Failed to mark as read", icon: Toast.Icon.error)
            }
        }
    }
    
    func copyPostURL(_ post: Post) {
        guard let page = currentPage else { return }
        
        // Manually construct URL since extension might not be accessible
        guard var components = URLComponents(url: ForumsClient.shared.baseURL!, resolvingAgainstBaseURL: true) else { return }
        components.path = "/showthread.php"
        
        var queryItems: [URLQueryItem] = [.init(name: "threadid", value: thread.threadID)]
        switch page {
        case .last:
            queryItems.append(.init(name: "goto", value: "lastpost"))
        case .nextUnread:
            queryItems.append(.init(name: "goto", value: "newpost"))
        case .specific(let pageNum):
            queryItems.append(.init(name: "pagenumber", value: "\(pageNum)"))
        }
        
        if let author = author {
            queryItems.append(.init(name: "userid", value: author.userID))
        }
        
        components.queryItems = queryItems
        components.fragment = "post\(post.postID)"
        
        guard let url = components.url else { return }
        
        UIPasteboard.general.coercedURL = url
        Toast.show(title: "Post URL copied", icon: Toast.Icon.link)
    }
    
    // MARK: - Thread Actions
    func toggleBookmark() {
        let bookmarked = !thread.bookmarked
        Task {
            do {
                try await ForumsClient.shared.setThread(thread, isBookmarked: bookmarked)
                thread.bookmarked = bookmarked
                try thread.managedObjectContext?.save()
                Toast.show(title: bookmarked ? "Bookmarked" : "Unbookmarked", 
                          icon: bookmarked ? Toast.Icon.bookmark : Toast.Icon.bookmarkSlash)
            } catch {
                logger.error("Could not set bookmark: \(error)")
                Toast.show(title: "Failed to update bookmark", icon: Toast.Icon.error)
            }
        }
    }
    
    func copyLink() {
        guard let page = currentPage else { return }
        
        // Manually construct URL since extension might not be accessible
        guard var components = URLComponents(url: ForumsClient.shared.baseURL!, resolvingAgainstBaseURL: true) else { return }
        components.path = "/showthread.php"
        
        var queryItems: [URLQueryItem] = [.init(name: "threadid", value: thread.threadID)]
        switch page {
        case .last:
            queryItems.append(.init(name: "goto", value: "lastpost"))
        case .nextUnread:
            queryItems.append(.init(name: "goto", value: "newpost"))
        case .specific(let pageNum):
            queryItems.append(.init(name: "pagenumber", value: "\(pageNum)"))
        }
        
        if let author = author {
            queryItems.append(.init(name: "userid", value: author.userID))
        }
        
        components.queryItems = queryItems
        guard let url = components.url else { return }
        
        UIPasteboard.general.coercedURL = url
        Toast.show(title: "Copied link", icon: Toast.Icon.link)
    }
    
    func showYourPosts(coordinator: (any MainCoordinator)?) {
        guard let loggedInUserID = loggedInUserID else { return }
        let authorKey = UserKey(userID: loggedInUserID, username: loggedInUsername)
        let author = User.objectForKey(objectKey: authorKey, in: thread.managedObjectContext!)
        
        // Navigate to filtered posts view
        coordinator?.navigateToThread(thread, page: .specific(1), author: author)
    }
    
    func vote(rating: Int) {
        Task {
            do {
                try await ForumsClient.shared.rate(thread, as: rating)
                Toast.show(title: "Voted \(rating) stars", icon: Toast.Icon.checkmark)
            } catch {
                logger.error("Failed to vote on thread: \(error)")
                Toast.show(title: "Failed to vote", icon: Toast.Icon.error)
            }
        }
    }
    
    // MARK: - FYAD Flag Support
    func handleFYADFlagRequest(onError: @escaping (String, String) -> Void = { _, _ in }) {
        flagRequest?.cancel()
        flagRequest = Task {
            let client = ForumsClient.shared
            if let forum = thread.forum {
                _ = try await client.flagForThread(in: forum)
            }
        }
        Task {
            do {
                try await flagRequest!.value
                // Note: Toast intentionally commented out like in original
                // Toast.show(title: "Thanks, I guess")
            } catch {
                logger.error("Could not flag thread: \(error)")
                await MainActor.run {
                    onError("Could not flag thread", error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Extensions
// Note: threadBookmarkDidChange is already declared in PostsPageViewController

