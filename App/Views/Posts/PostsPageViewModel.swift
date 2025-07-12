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
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil) {
        self.thread = thread
        self.author = author
        self.numberOfPages = Int(author != nil ? thread.filteredNumberOfPagesForAuthor(author!) : thread.numberOfPages)
    }
    
    deinit {
        networkOperation?.cancel()
    }
    
    // MARK: - Page Loading
    func loadInitialPage() {
        // Determine initial page based on thread state
        let initialPage: ThreadPage
        
        if thread.beenSeen && thread.anyUnreadPosts {
            initialPage = .nextUnread
        } else if thread.beenSeen {
            // Thread has been seen but no unread posts - go to last page
            initialPage = .last
        } else {
            // Thread hasn't been seen - go to first page
            initialPage = .specific(1)
        }
        
        loadPage(initialPage, updatingCache: true, updatingLastReadPost: false)
    }
    
    func loadPage(_ newPage: ThreadPage, updatingCache: Bool = true, updatingLastReadPost: Bool = true) {
        logger.info("Loading page: \(String(describing: newPage)) for thread: \(self.thread.title ?? "Unknown")")
        
        // Cancel any existing operation
        networkOperation?.cancel()
        
        // Update state
        currentPage = newPage
        hasAttemptedInitialScroll = false
        isReRenderingAfterMarkAsRead = false
        // Don't clear jumpToPostID if we have one set - it's needed for post navigation
        print("🎯 loadPage: jumpToPostID before potential clear: \(jumpToPostID ?? "nil")")
        if jumpToPostID == nil {
            scrollToFraction = nil
        }
        print("🎯 loadPage: jumpToPostID after state update: \(jumpToPostID ?? "nil")")
        
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
            logger.info("Starting network operation to fetch posts")
            let result = try await ForumsClient.shared.listPosts(
                in: thread,
                writtenBy: author,
                page: newPage,
                updateLastReadPost: updatingLastReadPost
            )
            
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
                if error is CancellationError || (error as? URLError)?.code == .cancelled {
                    logger.info("Network operation was cancelled")
                    return
                }
                
                logger.error("Failed to load posts: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
            
            networkOperation = nil
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
    
    // MARK: - Refresh
    func refresh() {
        guard let page = currentPage else { return }
        loadPage(page, updatingCache: true, updatingLastReadPost: false)
    }
    
    func refreshCurrentPage() async {
        guard let page = currentPage else { return }
        
        await withCheckedContinuation { continuation in
            loadPage(page, updatingCache: true, updatingLastReadPost: false)
            
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
    
    // MARK: - Scrolling
    private func handleInitialScrolling() {
        guard !hasAttemptedInitialScroll else { return }
        hasAttemptedInitialScroll = true
        
        // Skip scrolling if re-rendering after mark as read
        if isReRenderingAfterMarkAsRead {
            logger.info("Skipping initial scrolling - re-rendering after mark as read")
            isReRenderingAfterMarkAsRead = false
            return
        }
        
        // Priority 1: First unread post
        if let serverFirstUnreadIndex = firstUnreadPost {
            let clientFirstUnreadIndex = posts.firstIndex(where: { !$0.beenSeen })
            
            let actualIndex: Int
            if let clientIndex = clientFirstUnreadIndex {
                if clientIndex != serverFirstUnreadIndex {
                    logger.warning("Server firstUnreadPost (\(serverFirstUnreadIndex)) differs from client calculation (\(clientIndex))")
                    actualIndex = clientIndex
                } else {
                    actualIndex = clientIndex
                }
            } else {
                actualIndex = serverFirstUnreadIndex
            }
            
            if actualIndex < posts.count {
                let postID = posts[actualIndex].postID
                logger.info("Scrolling to first unread post: \(postID)")
                jumpToPostID = postID
            }
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
}

// MARK: - Extensions
// Note: threadBookmarkDidChange is already declared in PostsPageViewController

