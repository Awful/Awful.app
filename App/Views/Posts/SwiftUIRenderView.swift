//  SwiftUIRenderView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import CoreData
import Foundation
import Lottie
import SwiftUI
import UIKit
import WebKit
import Stencil
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIRenderView")

// MARK: - WebView Container Cache
private class WebViewContainerCache {
    static let shared = WebViewContainerCache()
    
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "WebViewContainerCache")
    private let maxCacheSize = 5 // Limit cache size to prevent memory issues
    
    private struct CacheEntry {
        let container: RenderViewContainer
        let timestamp: Date
        
        init(container: RenderViewContainer) {
            self.container = container
            self.timestamp = Date()
        }
    }
    
    init() {
        // Clean up cache when app receives memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func get(for key: String) -> RenderViewContainer? {
        queue.sync {
            return cache[key]?.container
        }
    }
    
    func set(_ container: RenderViewContainer, for key: String) {
        queue.async {
            self.cache[key] = CacheEntry(container: container)
            self.performCleanup()
        }
    }
    
    func remove(for key: String) {
        queue.async {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async {
            self.cache.removeAll()
        }
    }
    
    private func performCleanup() {
        guard cache.count > maxCacheSize else { return }
        
        // Remove oldest entries when cache exceeds max size
        let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
        
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    @objc private func handleMemoryWarning() {
        queue.async {
            // Clear half the cache on memory warning
            let sortedEntries = self.cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(self.cache.count / 2)
            
            for (key, _) in entriesToRemove {
                self.cache.removeValue(forKey: key)
            }
        }
    }
}

/// SwiftUI wrapper for RenderView that provides proper state management
struct SwiftUIRenderView: UIViewRepresentable {
    // MARK: - Dependencies
    @ObservedObject var viewModel: PostsPageViewModel
    let theme: Theme
    let onPostAction: (Post, CGRect) -> Void
    let onUserAction: (Post, CGRect) -> Void
    let onScrollChanged: ((Bool) -> Void)?
    let onPullChanged: ((PullData) -> Void)?
    let onRefreshTriggered: (() -> Void)?
    let onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)? // offset, contentHeight, viewHeight
    let onDragEnded: ((Bool) -> Void)? // willDecelerate
    let onDecelerationEnded: (() -> Void)? // scroll deceleration ended
    @Binding var replyWorkspace: IdentifiableReplyWorkspace?
    @Binding var presentedImageURL: URL?
    @Binding var showingImageViewer: Bool
    
    // MARK: - Content Insets
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    
    // MARK: - Immersive Mode
    var isImmersiveMode: Bool = false
    
    // Removed frog content parameters
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    @FoilDefaultStorage(Settings.enableCustomTitlePostLayout) private var enableCustomTitlePostLayout
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    
    
    // MARK: - UIViewRepresentable
    func makeUIView(context: UIViewRepresentableContext<SwiftUIRenderView>) -> RenderViewContainer {
        let pageKey: String
        if let currentPage = viewModel.currentPage {
            switch currentPage {
            case .last:
                pageKey = "last"
            case .nextUnread:
                pageKey = "nextUnread"
            case .specific(let pageNum):
                pageKey = "page\(pageNum)"
            }
        } else {
            pageKey = "unknown"
        }
        let cacheKey = "\(viewModel.thread.threadID)-\(viewModel.author?.userID ?? "no-author")-\(pageKey)"
        
        // Try to get cached container first
        if let cachedContainer = WebViewContainerCache.shared.get(for: cacheKey) {
            logger.info("🔄 Reusing cached RenderViewContainer for thread \(viewModel.thread.threadID) with key: \(cacheKey)")
            
            // Update delegates
            cachedContainer.delegate = context.coordinator
            cachedContainer.scrollDelegate = context.coordinator
            cachedContainer.setup(theme: theme)
            cachedContainer.setupContextMenu(coordinator: context.coordinator)
            
            // If the cached container has content, stop loading state
            if cachedContainer.hasContent {
                logger.info("🔄 Cached container has content, stopping loading state")
                DispatchQueue.main.async {
                    self.viewModel.isLoading = false
                }
            }
            
            // No need to re-render if we're reusing a cached container with content
            return cachedContainer
        }
        
        logger.info("🔄 Creating new RenderViewContainer for thread \(viewModel.thread.threadID) with key: \(cacheKey)")
        
        let container = RenderViewContainer()
        container.delegate = context.coordinator
        container.scrollDelegate = context.coordinator
        container.setup(theme: theme)
        container.setupContextMenu(coordinator: context.coordinator)
        
        // Set up JavaScript message handler for image clicks (alternative to coordinate system)
        container.renderView.webView.configuration.userContentController.add(
            ScriptMessageHandlerWeakTrampoline(context.coordinator), 
            name: "imageClicked"
        )
        
        // Cache the container
        WebViewContainerCache.shared.set(container, for: cacheKey)
        
        // Set up JavaScript image click handlers as alternative to coordinate system
        context.coordinator.setupImageClickHandlers(renderView: container.renderView)
        
        // IMMEDIATE RENDER: Always render posts from Core Data when container is created
        logger.info("🔄 makeUIView - viewModel has \(viewModel.posts.count) posts, currentPage: \(String(describing: viewModel.currentPage)), isLoading: \(viewModel.isLoading)")
        
        let postsToRender: [Post]
        if !viewModel.posts.isEmpty {
            logger.info("🔄 makeUIView - using \(viewModel.posts.count) posts from viewModel")
            postsToRender = viewModel.posts
        } else {
            logger.warning("🔄 makeUIView - no posts in viewModel, trying to fetch from Core Data")
            let cachedPosts = fetchCachedPosts(for: viewModel.thread, page: viewModel.currentPage)
            if !cachedPosts.isEmpty {
                logger.info("🔄 makeUIView - found \(cachedPosts.count) cached posts")
                postsToRender = cachedPosts
            } else {
                logger.warning("🔄 makeUIView - no cached posts found, container will be empty until posts are loaded")
                postsToRender = []
            }
        }
        
        if !postsToRender.isEmpty {
            container.renderPosts(
                posts: postsToRender,
                thread: viewModel.thread,
                author: viewModel.author,
                page: viewModel.currentPage,
                numberOfPages: viewModel.numberOfPages,
                firstUnreadPost: viewModel.firstUnreadPost,
                advertisementHTML: viewModel.advertisementHTML,
                theme: theme,
                fontScale: CGFloat(fontScale),
                showAvatars: showAvatars,
                showImages: showImages,
                enableCustomTitlePostLayout: enableCustomTitlePostLayout,
                frogAndGhostEnabled: frogAndGhostEnabled,
                loggedInUserID: loggedInUserID,
                loggedInUsername: loggedInUsername,
                forceRender: true
            )
        }
        
        return container
    }
    
    private func fetchCachedPosts(for thread: AwfulThread, page: ThreadPage?) -> [Post] {
        guard let context = thread.managedObjectContext else {
            logger.warning("🔄 Thread has no managed object context")
            return []
        }
        
        // Calculate the page number for fetching
        let pageNumber: Int
        switch page {
        case .specific(let number):
            pageNumber = number
        case .first:
            pageNumber = 1
        case .last:
            pageNumber = Int(thread.numberOfPages)
        case .nextUnread:
            // For next unread, we'll try to fetch the last seen page
            pageNumber = max(1, Int(thread.seenPosts / 40) + 1) // Assuming 40 posts per page
        case .none:
            pageNumber = 1
        }
        
        // Fetch posts for this thread and page
        let postsPerPage = 40 // Standard posts per page
        let startIndex = (pageNumber - 1) * postsPerPage + 1
        let endIndex = pageNumber * postsPerPage
        
        let posts = Post.fetch(in: context) { request in
            request.predicate = NSPredicate(format: "%K == %@ AND %K >= %d AND %K <= %d", 
                                          #keyPath(Post.thread), thread,
                                          #keyPath(Post.threadIndex), startIndex,
                                          #keyPath(Post.threadIndex), endIndex)
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Post.threadIndex), ascending: true)]
            request.returnsObjectsAsFaults = false
        }
        
        logger.info("🔄 Fetched \(posts.count) cached posts for thread \(thread.threadID) page \(pageNumber)")
        return posts
    }
    
    func updateUIView(_ container: RenderViewContainer, context: UIViewRepresentableContext<SwiftUIRenderView>) {
        // Update theme stylesheet in case it changed
        container.setup(theme: theme)
        
        // Update frog setting on container
        container.updateFrogAndGhostEnabled(frogAndGhostEnabled)
        
        // Removed frog content update - reverting to standard approach
        
        // Update immersive mode setting
        container.updateImmersiveMode(isImmersiveMode)
        
        // Force clear background for overscroll consistency
        let renderView = container.renderView
        renderView.backgroundColor = UIColor.clear
        renderView.scrollView.backgroundColor = theme[uicolor: "postsViewBackgroundColor"] ?? UIColor.systemBackground
        container.backgroundColor = theme[uicolor: "postsViewBackgroundColor"] ?? UIColor.systemBackground
        
        // Update content insets based on toolbar visibility
        container.updateContentInsets(top: topInset, bottom: bottomInset)
        
        // Only render if the container doesn't have content or if posts have actually changed
        if !viewModel.posts.isEmpty && !container.hasContent {
            logger.info("🔄 SwiftUI updateUIView - rendering content for container without content")
            
            container.renderPosts(
                posts: viewModel.posts,
                thread: viewModel.thread,
                author: viewModel.author,
                page: viewModel.currentPage,
                numberOfPages: viewModel.numberOfPages,
                firstUnreadPost: viewModel.firstUnreadPost,
                advertisementHTML: viewModel.advertisementHTML,
                theme: theme,
                fontScale: CGFloat(fontScale),
                showAvatars: showAvatars,
                showImages: showImages,
                enableCustomTitlePostLayout: enableCustomTitlePostLayout,
                frogAndGhostEnabled: frogAndGhostEnabled,
                loggedInUserID: loggedInUserID,
                loggedInUsername: loggedInUsername,
                forceRender: false
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(
            parent: self,
            onPostAction: onPostAction,
            onUserAction: onUserAction,
            viewModel: viewModel,
            replyWorkspace: $replyWorkspace,
            onScrollChanged: onScrollChanged,
            onPullChanged: onPullChanged,
            onRefreshTriggered: onRefreshTriggered,
            onScrollPositionChanged: onScrollPositionChanged,
            onDragEnded: onDragEnded,
            onDecelerationEnded: onDecelerationEnded
        )
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, RenderViewDelegate, RenderViewScrollDelegate {
        let parent: SwiftUIRenderView
        let onPostAction: (Post, CGRect) -> Void
        let onUserAction: (Post, CGRect) -> Void
        let onScrollChanged: ((Bool) -> Void)?
        let onPullChanged: ((PullData) -> Void)?
        let onRefreshTriggered: (() -> Void)?
        let onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?
        let onDragEnded: ((Bool) -> Void)?
        let onDecelerationEnded: (() -> Void)?
        weak var viewModel: PostsPageViewModel?
        private lazy var oEmbedFetcher = OEmbedFetcher()
        var replyWorkspace: Binding<IdentifiableReplyWorkspace?>?
        
        init(parent: SwiftUIRenderView,
             onPostAction: @escaping (Post, CGRect) -> Void, 
             onUserAction: @escaping (Post, CGRect) -> Void,
             viewModel: PostsPageViewModel,
             replyWorkspace: Binding<IdentifiableReplyWorkspace?>,
             onScrollChanged: ((Bool) -> Void)? = nil,
             onPullChanged: ((PullData) -> Void)? = nil,
             onRefreshTriggered: (() -> Void)? = nil,
             onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)? = nil,
             onDragEnded: ((Bool) -> Void)? = nil,
             onDecelerationEnded: (() -> Void)? = nil) {
            self.parent = parent
            self.onPostAction = onPostAction
            self.onUserAction = onUserAction
            self.viewModel = viewModel
            self.replyWorkspace = replyWorkspace
            self.onScrollChanged = onScrollChanged
            self.onPullChanged = onPullChanged
            self.onRefreshTriggered = onRefreshTriggered
            self.onScrollPositionChanged = onScrollPositionChanged
            self.onDragEnded = onDragEnded
            self.onDecelerationEnded = onDecelerationEnded
        }
        
        // MARK: - RenderViewDelegate
        func didFinishRenderingHTML(in view: RenderView) {
            if UserDefaults.standard.bool(forKey: Settings.embedTweets.key) {
                view.embedTweets()
            }
            
            // Reset rendering flag when HTML finishes loading
            DispatchQueue.main.async {
                if let container = view.superview as? RenderViewContainer {
                    container.isCurrentlyRendering = false
                }
            }
        }
        
        func didReceive(message: RenderViewMessage, in view: RenderView) {
            Task { @MainActor in
                await handle(message: message, in: view)
            }
        }
        
        func didTapPostActionButton(_ button: UIButton, in renderView: RenderView) {
            print("🔘 didTapPostActionButton called")
            Task {
                await MainActor.run {
                    // Get the post from the button position using JavaScript
                    let javascript = "Awful.posts.fromPoint(\(button.center.x), \(button.center.y))"
                    print("🔘 Executing JavaScript: \(javascript)")
                    Task {
                        do {
                            let result = try await renderView.webView.eval(javascript) as? [String: Any]
                            print("🔘 JavaScript result: \(String(describing: result))")
                            guard
                                let result = result,
                                let postID = result["postID"] as? String
                                else { 
                                    print("🔘 Failed to get postID from result")
                                    return 
                                }
                            
                            print("🔘 Found postID: \(postID)")
                            
                            // Find the post on the main actor
                            await MainActor.run {
                                guard let post = viewModel?.posts.first(where: { $0.postID == postID }) else { 
                                    print("🔘 Failed to find post with ID: \(postID)")
                                    print("🔘 Available posts: \(viewModel?.posts.map { $0.postID } ?? [])")
                                    return 
                                }
                                
                                print("🔘 Found post: \(post.postID)")
                                
                                // Convert button position to RenderViewContainer coordinates
                                let buttonPoint = button.center
                                print("🔘 Button point: \(buttonPoint)")
                                
                                // Show the context menu for this post
                                if let container = renderView.superview as? RenderViewContainer {
                                    print("🔘 Calling showContextMenu")
                                    container.showContextMenu(for: post, at: buttonPoint)
                                } else {
                                    print("🔘 Failed to find RenderViewContainer")
                                    print("🔘 renderView.superview: \(String(describing: renderView.superview))")
                                }
                            }
                        } catch {
                            print("🔘 Error: \(error)")
                            logger.error("Could not handle post action button tap: \(error, privacy: .public)")
                        }
                    }
                }
            }
        }
        
        func didTapLink(to url: URL, in view: RenderView) {
            // Handle link taps using the same logic as UIKit version
            logger.info("Link tapped: \(url)")
            print("🔗 SwiftUIRenderView: didTapLink called with URL: \(url)")
            
            // Try to handle as internal route first
            do {
                let route = try AwfulRoute(url)
                print("🔗 SwiftUIRenderView: Created route: \(route)")
                AppDelegate.instance.open(route: route)
                return
            } catch {
                print("🔗 SwiftUIRenderView: Failed to create route: \(error)")
            }
            
            // Handle external URLs based on user preferences
            if url.opensInBrowser {
                // Find the hosting view controller to present from
                if let hostingVC = findHostingViewController(from: view) {
                    URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: hostingVC)
                } else {
                    // Fallback to system default
                    UIApplication.shared.open(url)
                }
            } else {
                // Non-browser URL - open directly
                UIApplication.shared.open(url)
            }
        }
        
        func renderProcessDidTerminate(in view: RenderView) {
            // Reset render state on process termination
            logger.warning("🚨 Render process terminated, triggering re-render from Core Data")
            if let container = view.superview as? RenderViewContainer {
                container.resetRenderState()
                
                if container.isInBackground {
                    container.needsContentRestoration = true
                    logger.info("🔄 Marked WebView for content restoration after background")
                } else {
                    logger.info("🔄 Triggering immediate re-render from Core Data")
                    container.triggerContentRerender()
                }
                
                // Also force the view model to refresh if we have posts cached
                if let viewModel = self.viewModel {
                    logger.info("🔄 Forcing view model refresh with cached posts")
                    DispatchQueue.main.async {
                        viewModel.forceContentRerender()
                    }
                }
            }
        }
        
        // MARK: - Message Handling
        @MainActor
        private func handle(message: RenderViewMessage, in renderView: RenderView) async {
            guard let viewModel = viewModel else { return }
            
            switch message {
            case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
                logger.info("Tweets finished loading")
                
            case let message as RenderView.BuiltInMessage.FetchOEmbedFragment:
                do {
                    let fragment = await oEmbedFetcher.fetch(url: message.url, id: message.id)
                    let javascript = "Awful.invoke('oembed.process', \(fragment))"
                    try await renderView.webView.eval(javascript)
                } catch {
                    logger.error("OEmbed fetch failed: \(error)")
                }
                
            case let message as RenderView.BuiltInMessage.DidTapPostActionButton:
                guard message.postIndex < viewModel.posts.count else { return }
                let post = viewModel.posts[message.postIndex]
                // Show native context menu instead of custom overlay
                if let container = renderView.superview as? RenderViewContainer {
                    let point = CGPoint(x: message.frame.midX, y: message.frame.maxY)
                    container.showContextMenu(for: post, at: point)
                }
                
            case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
                guard message.postIndex < viewModel.posts.count else { return }
                let post = viewModel.posts[message.postIndex]
                // Show user actions context menu
                if let container = renderView.superview as? RenderViewContainer {
                    let point = CGPoint(x: message.frame.midX, y: message.frame.maxY)
                    container.showUserActionsMenu(for: post, at: point)
                }
                
            default:
                logger.error("Unhandled message: \(type(of: message))")
            }
        }
        
        // MARK: - RenderViewScrollDelegate
        func didScroll(isScrollingUp: Bool) {
            onScrollChanged?(isScrollingUp)
        }
        
        func didPull(data: PullData) {
            onPullChanged?(data)
        }
        
        func didTriggerRefresh() {
            onRefreshTriggered?()
        }
        
        func didUpdateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
            onScrollPositionChanged?(offset, contentHeight, viewHeight)
        }
        
        func didEndDragging(willDecelerate: Bool) {
            onDragEnded?(willDecelerate)
        }
        
        func didEndDecelerating() {
            // Handle any cleanup needed after deceleration
            // For now, just ensure pull states are reset
            let resetPullData = PullData(topFraction: 0, bottomFraction: 0)
            onPullChanged?(resetPullData)
        }
        
        // MARK: - Helper Methods
        private func findHostingViewController(from view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while responder != nil {
                if let viewController = responder as? UIViewController {
                    return viewController
                }
                responder = responder?.next
            }
            return nil
        }
        
        // MARK: - Alternative JavaScript-based Image Detection
        func setupImageClickHandlers(renderView: RenderView) {
            Task {
                // Add click handlers to all images via JavaScript
                // This bypasses the coordinate system entirely
                let setupJS = """
                    // Remove any existing handlers
                    document.removeEventListener('click', window.awfulImageClickHandler);
                    
                    // Create a new handler
                    window.awfulImageClickHandler = function(event) {
                        const target = event.target;
                        if (target.tagName === 'IMG' && 
                            (target.classList.contains('timg') || target.classList.contains('img'))) {
                            // Found an image we want to handle (timg or img classes)
                            event.preventDefault();
                            event.stopPropagation();
                            
                            // Send message to native side
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.imageClicked) {
                                window.webkit.messageHandlers.imageClicked.postMessage({
                                    src: target.src,
                                    className: target.className,
                                    title: target.title || target.alt || ''
                                });
                            }
                        }
                    };
                    
                    // Add the event listener
                    document.addEventListener('click', window.awfulImageClickHandler, true);
                """
                
                do {
                    try await renderView.webView.eval(setupJS)
                    logger.info("🖼️ Set up JavaScript image click handlers")
                } catch {
                    logger.error("🖼️ Failed to set up JavaScript image handlers: \(error)")
                }
            }
        }
        
        // MARK: - SwiftUI Image Handling
        func handleInterestingElements(_ elements: [RenderView.InterestingElement], from presentingViewController: UIViewController, renderView: RenderView) -> Bool {
            logger.info("🖼️ SwiftUI handling \(elements.count) elements")
            
            // Debug: log all elements
            for element in elements {
                switch element {
                case .spoiledImage(let title, let url, let frame, _):
                    logger.info("🖼️ Found spoiled image: \(title) at \(url), frame: \(String(describing: frame))")
                case .spoiledLink(_, let url):
                    logger.info("🔗 Found spoiled link: \(url)")
                case .spoiledVideo(_, let url):
                    logger.info("🎥 Found spoiled video: \(url)")
                case .unspoiledLink(let frame, let url):
                    logger.info("🔗 Found unspoiled link: \(url) at frame: \(String(describing: frame))")
                }
            }
            
            // Handle unspoiled links by showing URL context menu
            for case let .unspoiledLink(frame: frame, url: url) in elements {
                if !frame.isEmpty && url.absoluteString != "about:blank" {
                    logger.info("🔗 Presenting context menu for unspoiled link: \(url)")
                    
                    // Use URLMenuPresenter to show context menu for the unspoiled link
                    let urlMenuPresenter = URLMenuPresenter(linkURL: url)
                    let sourceRect = CGRect(origin: CGPoint(x: frame.midX, y: frame.midY), size: CGSize(width: 1, height: 1))
                    
                    DispatchQueue.main.async {
                        urlMenuPresenter.present(fromViewController: presentingViewController, fromRect: sourceRect, inView: renderView)
                    }
                    return true
                }
            }
            
            // Collect all spoiled images and choose the best one
            var candidateImages: [(title: String, url: URL, frame: CGRect?, location: RenderView.LocationWithinPost?)] = []
            
            for case let .spoiledImage(title: title, url: url, frame: frame, location: location) in elements {
                candidateImages.append((title: title, url: url, frame: frame, location: location))
            }
            
            // If we have multiple images, prefer smaller ones (likely foreground elements)
            // This helps when larger images are layered behind smaller ones
            if candidateImages.count > 1 {
                logger.info("🖼️ Multiple images found (\(candidateImages.count)), choosing best candidate")
                
                // Sort by frame area (smaller first) - smaller images are likely foreground elements
                candidateImages.sort { (image1, image2) in
                    guard let frame1 = image1.frame, let frame2 = image2.frame else {
                        return image1.frame != nil // Prefer images with frames
                    }
                    let area1 = frame1.width * frame1.height
                    let area2 = frame2.width * frame2.height
                    return area1 < area2
                }
                
                for (index, candidate) in candidateImages.enumerated() {
                    let frameArea = (candidate.frame?.width ?? 0) * (candidate.frame?.height ?? 0)
                    logger.info("🖼️ Candidate \(index): \(candidate.title) at \(candidate.url), frame area: \(frameArea)")
                }
            }
            
            // Take the best candidate (first after sorting, or just first if single image)
            if let bestImage = candidateImages.first {
                logger.info("🖼️ Selected best image: \(bestImage.title) at \(bestImage.url)")
                
                if let imageURL = URL(string: bestImage.url.absoluteString, relativeTo: ForumsClient.shared.baseURL) {
                    logger.info("🖼️ Presenting image in SwiftUI sheet: \(imageURL)")
                    
                    // Check current state before presenting
                    logger.info("🖼️ Current state - presentedImageURL: \(String(describing: self.parent.presentedImageURL)), showingImageViewer: \(self.parent.showingImageViewer)")
                    
                    // Present image in SwiftUI sheet on main thread
                    // Clear any previous state first to avoid interference
                    DispatchQueue.main.async {
                        // Ensure we're not already showing an image viewer
                        if !self.parent.showingImageViewer {
                            // Clear any previous URL first
                            self.parent.presentedImageURL = nil
                            // Set new URL and show viewer in the next run loop to ensure clean state
                            DispatchQueue.main.async {
                                self.parent.presentedImageURL = imageURL
                                self.parent.showingImageViewer = true
                                logger.info("🖼️ Set presentedImageURL to: \(imageURL), showingImageViewer: true")
                            }
                        } else {
                            logger.info("🖼️ Image viewer already showing, skipping presentation")
                        }
                    }
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - JavaScript Message Handling
extension SwiftUIRenderView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.info("🔄 Received JavaScript message: \(message.name)")
        
        // Handle image clicks from JavaScript (bypasses coordinate system)
        if message.name == "imageClicked", let messageBody = message.body as? [String: Any] {
            logger.info("🖼️ JavaScript image click detected: \(messageBody)")
            
            if let src = messageBody["src"] as? String, let imageURL = URL(string: src) {
                logger.info("🖼️ Presenting image from JavaScript click: \(imageURL)")
                
                // Present image directly without coordinate system
                DispatchQueue.main.async {
                    self.parent.presentedImageURL = imageURL
                    self.parent.showingImageViewer = true
                }
            }
        }
    }
}

// MARK: - Pull Data Structure
struct PullData {
    let topFraction: CGFloat      // Top overscroll fraction (0.0 to 1.0)
    let bottomFraction: CGFloat   // Bottom overscroll fraction (0.0 to 1.0)
}

// MARK: - Scroll Delegate Protocol
protocol RenderViewScrollDelegate: AnyObject {
    func didScroll(isScrollingUp: Bool)
    func didPull(data: PullData)
    func didTriggerRefresh()
    func didUpdateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat)
    func didEndDragging(willDecelerate: Bool)
    func didEndDecelerating()
}

// MARK: - RenderView Container
class RenderViewContainer: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate, WKUIDelegate {
    private let _renderView = RenderView()
    var renderView: RenderView { _renderView }
    weak var delegate: RenderViewDelegate? {
        didSet {
            _renderView.delegate = delegate
        }
    }
    weak var scrollDelegate: RenderViewScrollDelegate?
    private var lastScrollOffset: CGFloat = 0
    private var lastPullData: PullData = PullData(topFraction: 0, bottomFraction: 0)
    internal var lastRenderedPostsHash: Int = 0
    fileprivate var isCurrentlyRendering: Bool = false
    private var frogAndGhostEnabled: Bool = false
    private var isImmersiveMode: Bool = false
    private weak var coordinator: SwiftUIRenderView.Coordinator?
    
    /// A hidden button that we misuse to show a proper iOS context menu on tap (as opposed to long-tap).
    private lazy var hiddenMenuButton: HiddenMenuButton = {
        let postActionButton = HiddenMenuButton()
        postActionButton.alpha = 0
        if #available(iOS 16.0, *) {
            postActionButton.preferredMenuElementOrder = .fixed
        }
        addSubview(postActionButton)
        return postActionButton
    }()
    
    
    // Removed frog content properties
    
    // MARK: - Background/Foreground State Management
    internal var isInBackground: Bool = false
    private var savedScrollPosition: CGFloat = 0
    private var savedContentSize: CGSize = .zero
    internal var needsContentRestoration: Bool = false
    
    // MARK: - Content State
    internal var hasContent: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupRenderView()
        setupApplicationLifecycleObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRenderView()
        setupApplicationLifecycleObservers()
    }
    
    deinit {
        logger.info("🔄 RenderViewContainer deinit - removing lifecycle observers")
        removeApplicationLifecycleObservers()
    }
    
    private func setupRenderView() {
        addSubview(_renderView)
        _renderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _renderView.topAnchor.constraint(equalTo: topAnchor),
            _renderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            _renderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            _renderView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Register built-in messages
        _renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        _renderView.registerMessage(RenderView.BuiltInMessage.DidTapPostActionButton.self)
        _renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        _renderView.registerMessage(RenderView.BuiltInMessage.FetchOEmbedFragment.self)
        
        // Set up scroll delegate
        _renderView.scrollView.delegate = self
        
        // Set up long press gesture recognizer for images and links
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressRenderView(_:)))
        longPressGesture.delegate = self
        _renderView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Application Lifecycle Management
    private func setupApplicationLifecycleObservers() {
        logger.info("🔄 Setting up application lifecycle observers")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Listen for additional background/foreground notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        logger.info("🔄 Application lifecycle observers setup complete")
    }
    
    private func removeApplicationLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func applicationWillResignActive() {
        logger.info("🔄 Application will resign active - preparing WebView for background")
        prepareWebViewForBackground()
    }
    
    @objc private func applicationDidBecomeActive() {
        logger.info("🔄 Application did become active - restoring WebView from background")
        restoreWebViewFromBackground()
    }
    
    @objc private func applicationDidReceiveMemoryWarning() {
        logger.warning("Application received memory warning - preparing WebView for potential termination")
        prepareWebViewForBackground()
    }
    
    @objc private func applicationWillEnterForeground() {
        logger.info("🔄 Application will enter foreground - restoring WebView")
        restoreWebViewFromBackground()
    }
    
    @objc private func applicationDidEnterBackground() {
        logger.info("🔄 Application did enter background - preparing WebView for background")
        prepareWebViewForBackground()
    }
    
    // MARK: - WebView State Management
    private func prepareWebViewForBackground() {
        guard !isInBackground else { return }
        
        isInBackground = true
        
        // Save current scroll position and content state
        let scrollView = _renderView.scrollView
        savedScrollPosition = scrollView.contentOffset.y
        savedContentSize = scrollView.contentSize
        
        // Set WebView to opaque to prevent process termination
        _renderView.webView.isOpaque = true
        
        logger.info("🔄 WebView prepared for background - saved scroll position and content size, now opaque: \(self._renderView.webView.isOpaque)")
    }
    
    private func restoreWebViewFromBackground() {
        guard isInBackground else { return }
        
        isInBackground = false
        
        // Restore WebView to transparent for proper rendering
        _renderView.webView.isOpaque = false
        
        // Always check if content needs restoration by testing WebView content
        checkAndRestoreContentIfNeeded()
        
        logger.info("🔄 WebView restored from background - opaque: \(self._renderView.webView.isOpaque)")
    }
    
    private func checkAndRestoreContentIfNeeded() {
        // Check content with progressive delays to handle various restoration scenarios
        performContentCheck(attempt: 1, maxAttempts: 3)
    }
    
    private func performContentCheck(attempt: Int, maxAttempts: Int) {
        // Progressive delay: 0.5s, 1.0s, 1.5s
        let delay = TimeInterval(attempt) * 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            Task {
                do {
                    // Check for both empty content and error states
                    let contentCheck = try await self._renderView.webView.eval("""
                        (function() {
                            if (!document.body) return { empty: true, error: false };
                            var childCount = document.body.children.length;
                            // Check for common error indicators
                            var hasErrorPage = document.body.innerHTML.includes('about:blank') || 
                                               document.body.innerHTML.includes('error') ||
                                               document.body.innerHTML.includes('Problem loading page');
                            var hasMinimalContent = childCount < 2; // Expect at least header and main content
                            return { 
                                empty: childCount === 0, 
                                error: hasErrorPage,
                                minimal: hasMinimalContent,
                                count: childCount 
                            };
                        })()
                    """)
                    
                    if let checkResult = contentCheck as? [String: Any] {
                        let isEmpty = checkResult["empty"] as? Bool ?? true
                        let hasError = checkResult["error"] as? Bool ?? false
                        let hasMinimalContent = checkResult["minimal"] as? Bool ?? false
                        let childCount = checkResult["count"] as? Int ?? 0
                        
                        if isEmpty || hasError || hasMinimalContent {
                            logger.info("🔄 WebView needs restoration (attempt \(attempt)): empty=\(isEmpty), error=\(hasError), minimal=\(hasMinimalContent), count=\(childCount)")
                            self.delegate?.renderProcessDidTerminate(in: self._renderView)
                        } else {
                            logger.info("🔄 WebView content is healthy (\(childCount) elements), restoring scroll position")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                self?.restoreScrollPosition()
                            }
                        }
                    } else {
                        throw NSError(domain: "ContentCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid content check result"])
                    }
                } catch {
                    logger.warning("🔄 Content check failed (attempt \(attempt)): \(error)")
                    
                    if attempt < maxAttempts {
                        // Retry with longer delay
                        self.performContentCheck(attempt: attempt + 1, maxAttempts: maxAttempts)
                    } else {
                        // Final attempt failed, assume content needs restoration
                        logger.warning("🔄 All content check attempts failed, forcing restoration")
                        self.delegate?.renderProcessDidTerminate(in: self._renderView)
                    }
                }
            }
        }
    }
    
    private func restoreScrollPosition() {
        guard savedScrollPosition > 0 else { return }
        
        let scrollView = _renderView.scrollView
        let targetOffset = CGPoint(x: 0, y: savedScrollPosition)
        
        // Only restore if content size is similar to what we saved
        if abs(scrollView.contentSize.height - savedContentSize.height) < 100 {
            scrollView.setContentOffset(targetOffset, animated: false)
            logger.info("Restored scroll position")
        } else {
            logger.info("Content size changed significantly, skipping scroll restoration")
        }
    }
    
    // MARK: - Content Restoration Support  
    func triggerContentRerender() {
        // This method can be used to trigger re-rendering of posts
        // It would typically be called by the view model
        logger.info("🔄 Triggering content re-render after process termination")
        
        // Mark for content restoration if needed
        needsContentRestoration = true
        
        // Notify delegate about the need for re-rendering
        delegate?.renderProcessDidTerminate(in: _renderView)
    }
    
    func verifyContentPresence() {
        // Verify that the WebView actually has content, and restore if needed
        Task {
            do {
                let result = try await _renderView.webView.eval("""
                    (function() {
                        if (!document.body) return { hasContent: false, reason: 'no body' };
                        var childCount = document.body.children.length;
                        var hasErrorPage = document.body.innerHTML.includes('about:blank') || 
                                          document.body.innerHTML.includes('error') ||
                                          document.body.innerHTML.includes('Problem loading page');
                        var hasMinimalContent = childCount < 2;
                        return { 
                            hasContent: childCount > 0 && !hasErrorPage && !hasMinimalContent,
                            reason: hasErrorPage ? 'error page' : hasMinimalContent ? 'minimal content' : 'empty',
                            count: childCount 
                        };
                    })()
                """)
                
                if let checkResult = result as? [String: Any] {
                    let hasContent = checkResult["hasContent"] as? Bool ?? false
                    let reason = checkResult["reason"] as? String ?? "unknown"
                    let childCount = checkResult["count"] as? Int ?? 0
                    
                    if hasContent {
                        logger.info("🔄 Content verification passed - WebView has \(childCount) elements")
                        self.hasContent = true
                    } else {
                        logger.warning("🔄 Content verification failed - \(reason), count: \(childCount), triggering re-render")
                        self.hasContent = false
                        delegate?.renderProcessDidTerminate(in: _renderView)
                    }
                } else {
                    throw NSError(domain: "ContentVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid verification result"])
                }
            } catch {
                logger.warning("🔄 Content verification failed - JavaScript error: \(error)")
                hasContent = false
                delegate?.renderProcessDidTerminate(in: _renderView)
            }
        }
    }
    func setup(theme: Theme) {
        _renderView.setThemeStylesheet(theme[string: "postsViewCSS"] ?? "")
        
        // Apply scroll indicator style from theme
        _renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        
        // Set comprehensive background colors for overscroll consistency
        let backgroundColor = theme[uicolor: "postsViewBackgroundColor"] ?? UIColor.systemBackground
        _renderView.scrollView.backgroundColor = backgroundColor
        _renderView.backgroundColor = backgroundColor
        self.backgroundColor = backgroundColor
        
        // Also set the WebView container background
        if let webViewBackground = _renderView.webView.superview {
            webViewBackground.backgroundColor = backgroundColor
        }
    }
    
    func setupContextMenu(coordinator: SwiftUIRenderView.Coordinator) {
        self.coordinator = coordinator
        _renderView.webView.uiDelegate = self
    }
    
    func renderPosts(
        posts: [Post],
        thread: AwfulThread,
        author: User?,
        page: ThreadPage?,
        numberOfPages: Int,
        firstUnreadPost: Int?,
        advertisementHTML: String?,
        theme: Theme,
        fontScale: CGFloat,
        showAvatars: Bool,
        showImages: Bool,
        enableCustomTitlePostLayout: Bool,
        frogAndGhostEnabled: Bool,
        loggedInUserID: String?,
        loggedInUsername: String?,
        forceRender: Bool = false
    ) {
        // Create a hash of the current rendering state to prevent unnecessary re-renders
        let currentPostsHash = posts.map { $0.postID }.joined().hashValue
        
        // Skip rendering if we're already rendering the same posts or if we're currently in a render operation
        // unless forceRender is true
        guard (forceRender || currentPostsHash != lastRenderedPostsHash) && !isCurrentlyRendering else {
            logger.info("Skipping render - already rendered these \(posts.count) posts or render in progress")
            return
        }
        
        isCurrentlyRendering = true
        lastRenderedPostsHash = currentPostsHash
        logger.info("🔄 Rendering \(posts.count) posts (forceRender: \(forceRender))")
        
        let context = RenderContext(
            advertisementHTML: advertisementHTML,
            author: author,
            firstUnreadPost: firstUnreadPost,
            fontScale: Int(fontScale),
            hiddenPosts: 0,
            isBookmarked: thread.bookmarked,
            isLoggedIn: loggedInUserID != nil,
            posts: posts,
            showAvatars: showAvatars,
            showImages: showImages,
            stylesheet: theme[string: "postsViewCSS"] ?? "",
            theme: theme,
            username: loggedInUsername,
            enableCustomTitlePostLayout: enableCustomTitlePostLayout,
            enableFrogAndGhost: frogAndGhostEnabled
        )
        
        var contextDict = context.makeDictionary()
        contextDict["threadID"] = thread.threadID
        contextDict["forumID"] = thread.forum?.forumID ?? ""
        
        // Only show end message on the last page and when not filtering by author
        let isLastPage: Bool
        if let page = page {
            switch page {
            case .last:
                isLastPage = true
            case .specific(let n):
                isLastPage = n == numberOfPages
            case .nextUnread:
                isLastPage = false
            }
        } else {
            isLastPage = false
        }
        contextDict["endMessage"] = isLastPage && author == nil
        
        do {
            let html = try StencilEnvironment.shared.renderTemplate(.postsView, context: contextDict)
            _renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
            _renderView.loadLottiePlayer()
            
            logger.info("Posts rendering completed")
            hasContent = true
        } catch {
            logger.error("Template rendering failed: \(error)")
            // Reset rendering flag on error
            isCurrentlyRendering = false
        }
        
        // Reset rendering flag after completion
        isCurrentlyRendering = false
    }
    
    func jumpToPost(identifiedBy postID: String) {
        _renderView.jumpToPost(identifiedBy: postID)
    }
    
    func resetRenderState() {
        isCurrentlyRendering = false
        lastRenderedPostsHash = 0
        hasContent = false
    }
    
    
    func updateContentInsets(top: CGFloat, bottom: CGFloat) {
        let scrollView = _renderView.scrollView
        var currentInsets = scrollView.contentInset
        
        // Only update if insets have changed to avoid unnecessary layout
        if currentInsets.top != top || currentInsets.bottom != bottom {
            currentInsets.top = top
            currentInsets.bottom = bottom
            scrollView.contentInset = currentInsets
            
            // Update scroll indicator insets to match content insets
            scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            scrollView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            
            logger.info("Updated content insets: top=\(top), bottom=\(bottom)")
        }
    }
    
    func updateFrogAndGhostEnabled(_ enabled: Bool) {
        // Only update and log if the value actually changes
        guard frogAndGhostEnabled != enabled else {
            return
        }
        
        frogAndGhostEnabled = enabled
        logger.info("Updated frogAndGhostEnabled: \(enabled)")
        
        // Reset pull state when frog and ghost is disabled
        if !enabled {
            let resetPullData = PullData(topFraction: 0.0, bottomFraction: 0.0)
            scrollDelegate?.didPull(data: resetPullData)
        }
    }
    
    // Removed all custom frog implementation
    
    // This method is no longer needed as we're using HTML injection
    // private func createFrogAnimationView(theme: Theme) -> UIView { ... }
    
    // Removed frog animation update
    
    func updateImmersiveMode(_ enabled: Bool) {
        // Only update and log if the value actually changes
        guard isImmersiveMode != enabled else {
            return
        }
        
        isImmersiveMode = enabled
        
        // Update the background color to match the posts view background when in immersive mode
        if enabled {
            // Use clear background so the SwiftUI background shows through
            _renderView.backgroundColor = UIColor.clear
        } else {
            // Use clear background for normal mode
            _renderView.backgroundColor = UIColor.clear
        }
        
        logger.info("Updated immersive mode: \(enabled)")
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        let scrollDiff = currentOffset - lastScrollOffset
        let contentHeight = scrollView.contentSize.height
        let viewHeight = scrollView.bounds.height
        
        // Throttle scroll position updates to reduce overhead
        let shouldUpdatePosition = abs(scrollDiff) > 3 || abs(currentOffset - lastScrollOffset) > 10
        if shouldUpdatePosition {
            scrollDelegate?.didUpdateScrollPosition(
                offset: currentOffset,
                contentHeight: contentHeight,
                viewHeight: viewHeight
            )
        }
        
        // Calculate pull progress with reduced overhead
        if frogAndGhostEnabled {
            let isOverscrolling = currentOffset < -5 || (currentOffset + viewHeight > contentHeight + 20)
            
            if isOverscrolling {
                let bottomMaxPullDistance: CGFloat = 120 // Reasonable distance for bottom pull
                let topMaxPullDistance: CGFloat = 100 // Reasonable distance for top pull to avoid accidental triggers
                var topFraction: CGFloat = 0.0
                var bottomFraction: CGFloat = 0.0
                
                // Check for top overscroll (negative offset for refresh)
                if currentOffset < 0 {
                    let topOverscroll = abs(currentOffset)
                    if topOverscroll > 2 {
                        topFraction = min(max(topOverscroll / topMaxPullDistance, 0), 1.0)
                    }
                }
                
                // Check for bottom overscroll (for pull-for-next when enabled)
                if UserDefaults.standard.bool(forKey: Settings.pullForNext.key) {
                    let bottomOffset = currentOffset + viewHeight
                    let bottomOverscroll = bottomOffset - contentHeight
                    
                    // Only calculate pull progress when actually overscrolling and content is substantial
                    // Require some buffer space to prevent accidental triggers
                    if bottomOverscroll > 15 && contentHeight > viewHeight {
                        bottomFraction = min(max((bottomOverscroll - 10) / bottomMaxPullDistance, 0), 1.0)
                    }
                }
                
                // Send pull data only when there's a meaningful change
                let pullData = PullData(topFraction: topFraction, bottomFraction: bottomFraction)
                if abs(pullData.topFraction - lastPullData.topFraction) > 0.05 || 
                   abs(pullData.bottomFraction - lastPullData.bottomFraction) > 0.05 {
                    lastPullData = pullData
                    scrollDelegate?.didPull(data: pullData)
                }
            } else if lastPullData.topFraction > 0 || lastPullData.bottomFraction > 0 {
                // Reset pull data when not overscrolling
                lastPullData = PullData(topFraction: 0, bottomFraction: 0)
                scrollDelegate?.didPull(data: lastPullData)
            }
        }
        
        // Use a smaller threshold for more responsive toolbar updates
        let threshold: CGFloat = 3
        let isSignificantScroll = abs(scrollDiff) > threshold
        
        if isSignificantScroll {
            let isScrollingUp = scrollDiff < 0
            scrollDelegate?.didScroll(isScrollingUp: isScrollingUp)
            lastScrollOffset = currentOffset
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Reset the last scroll offset when user begins dragging
        // This helps with more accurate direction detection
        lastScrollOffset = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Notify delegate about drag end - this is important for pull-to-refresh release detection
        scrollDelegate?.didEndDragging(willDecelerate: decelerate)
        
        if !decelerate {
            // If scroll view won't decelerate, reset tracking for next gesture
            lastScrollOffset = scrollView.contentOffset.y
            // Also reset pull data if we're not decelerating
            if lastPullData.topFraction > 0 || lastPullData.bottomFraction > 0 {
                lastPullData = PullData(topFraction: 0, bottomFraction: 0)
                scrollDelegate?.didPull(data: lastPullData)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Reset tracking when scroll animation ends
        lastScrollOffset = scrollView.contentOffset.y
        
        // Reset pull data when deceleration ends to prevent stuck states
        if lastPullData.topFraction > 0 || lastPullData.bottomFraction > 0 {
            lastPullData = PullData(topFraction: 0, bottomFraction: 0)
            scrollDelegate?.didPull(data: lastPullData)
        }
        
        // Notify delegate that deceleration ended
        scrollDelegate?.didEndDecelerating()
    }
    
    // MARK: - Long Press Gesture Handling
    @objc private func didLongPressRenderView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        // Find the hosting view controller to present from
        guard let hostingVC = findHostingViewController() else {
            logger.warning("Could not find hosting view controller for long press")
            return
        }
        
        Task {
            let location = sender.location(in: _renderView)
            print("🖼️ Long press detected at location: \(location)")
            
            // Use the original proven UIKit method: interestingElements
            let elements = await _renderView.interestingElements(at: location)
            print("🖼️ Found \(elements.count) interesting elements")
            
            // Use the original UIKit logic for handling elements
            if let coordinator = coordinator {
                let handled = coordinator.handleInterestingElements(elements, from: hostingVC, renderView: _renderView)
                if !handled {
                    print("🖼️ No interesting elements found to handle")
                }
            }
        }
    }
    
    private func findHostingViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't interfere with unpop gestures - let them handle their own simultaneous recognition logic
        if otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            // If it's a right-edge pan gesture (likely unpop), don't allow simultaneous recognition
            if let screenEdgePan = otherGestureRecognizer as? UIScreenEdgePanGestureRecognizer,
               screenEdgePan.edges.contains(.right) {
                logger.info("🔄 Refusing simultaneous recognition with right-edge pan gesture to allow unpop")
                return false
            }
            // Allow left-edge gestures (for navigation back)
            if let screenEdgePan = otherGestureRecognizer as? UIScreenEdgePanGestureRecognizer,
               screenEdgePan.edges.contains(.left) {
                logger.info("🔄 Allowing simultaneous recognition with left-edge pan gesture for navigation")
                return true
            }
        }
        
        // Allow simultaneous recognition for other gestures (like long press with scrolling)
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Make sure our gestures don't interfere with system navigation gestures
        if otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            if let screenEdgePan = otherGestureRecognizer as? UIScreenEdgePanGestureRecognizer,
               screenEdgePan.edges.contains(.left) {
                logger.info("🔄 Allowing left-edge pan gesture to take precedence over our gesture")
                return true
            }
        }
        return false
    }
    
    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        // For now, return nil to use default behavior
        // We'll handle context menus through the post action button messages
        completionHandler(nil)
    }
    
    
    // Method to show context menu for post actions (called by coordinator)
    func showContextMenu(for post: Post, at point: CGPoint) {
        guard let coordinator = coordinator,
              let viewModel = coordinator.viewModel else { 
            return 
        }
        
        // Create UIMenu with the same structure as SwiftUI Menu
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        var actions: [UIAction] = []
        
        // Quote action
        actions.append(UIAction(title: "Quote", image: UIImage(named: "quote-post")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            viewModel.quotePost(post) { workspace in
                coordinator.replyWorkspace?.wrappedValue = IdentifiableReplyWorkspace(workspace: workspace)
            }
        })
        
        // Mark as read action
        actions.append(UIAction(title: "Mark as Read Up To Here", image: UIImage(named: "mark-read-up-to-here")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            viewModel.markAsReadUpTo(post)
        })
        
        // Share action
        actions.append(UIAction(title: "Share", image: UIImage(named: "share")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentSharePost(post)
        })
        
        // Report action
        actions.append(UIAction(title: "Report", image: UIImage(named: "rap-sheet")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentReportPost(post)
        })
        
        let menu = UIMenu(title: "", children: actions)
        hiddenMenuButton.show(menu: menu, from: CGRect(origin: point, size: CGSize(width: 1, height: 1)))
    }
    
    // Method to show user actions context menu (called by coordinator)
    func showUserActionsMenu(for post: Post, at point: CGPoint) {
        guard let coordinator = coordinator,
              let author = post.author else { return }
        
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        var actions: [UIAction] = []
        
        // Profile action
        actions.append(UIAction(title: "Profile", image: UIImage(named: "user-profile")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentUserProfile(userID: author.userID)
        })
        
        // Send Private Message action (if user can receive messages)
        if author.canReceivePrivateMessages == true {
            actions.append(UIAction(title: "Send Private Message", image: UIImage(named: "send-private-message")?.withRenderingMode(.alwaysTemplate)) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentPrivateMessageComposer(for: author)
            })
        }
        
        // User's Posts in This Thread action
        actions.append(UIAction(title: "User's Posts in This Thread", image: UIImage(named: "single-users-posts")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            if let viewModel = coordinator.viewModel {
                // Navigate to same thread but filtered by this user
                AppDelegate.instance.mainCoordinator?.navigateToThread(viewModel.thread, page: .specific(1), author: author)
            }
        })
        
        // Rap Sheet action
        actions.append(UIAction(title: "Rap Sheet", image: UIImage(named: "rap-sheet")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentRapSheet(userID: author.userID)
        })
        
        let menu = UIMenu(title: author.username ?? "", children: actions)
        hiddenMenuButton.show(menu: menu, from: CGRect(origin: point, size: CGSize(width: 1, height: 1)))
    }
    
}

// MARK: - Render Context
private struct RenderContext {
    let advertisementHTML: String?
    let author: User?
    let firstUnreadPost: Int?
    let fontScale: Int
    let hiddenPosts: Int
    let isBookmarked: Bool
    let isLoggedIn: Bool
    let posts: [Post]
    let showAvatars: Bool
    let showImages: Bool
    let stylesheet: String
    let theme: Theme
    let username: String?
    let enableCustomTitlePostLayout: Bool
    let enableFrogAndGhost: Bool
    
    func makeDictionary() -> [String: Any] {
        var context: [String: Any] = [
            "advertisementHTML": "",
            "externalStylesheet": "",
            "firstUnreadPost": firstUnreadPost as Any,
            "fontScale": fontScale,
            "hiddenPosts": hiddenPosts,
            "isBookmarked": isBookmarked,
            "isLoggedIn": isLoggedIn,
            "posts": posts.map { PostRenderModel($0, enableCustomTitlePostLayout: enableCustomTitlePostLayout).asDictionary(showAvatars: showAvatars) },
            "script": "",
            "showAvatars": showAvatars,
            "showImages": showImages,
            "stylesheet": stylesheet,
            "threadID": "",
            "forumID": "",
            "tweetTheme": theme[string: "mode"] ?? "light",
            "enableFrogAndGhost": enableFrogAndGhost,
            "endMessage": false,
            "username": username as Any,
            "enableCustomTitlePostLayout": enableCustomTitlePostLayout
        ]
        
        if enableFrogAndGhost {
            let ghostUrl = Bundle.main.url(forResource: "ghost60", withExtension: "json")!
            let ghostData = try! Data(contentsOf: ghostUrl)
            context["ghostJsonData"] = String(data: ghostData, encoding: .utf8) as Any
        }
        
        if let author = author {
            context["author"] = UserRenderModel(author, enableCustomTitlePostLayout: enableCustomTitlePostLayout).asDictionary(showAvatars: showAvatars)
        }
        
        return context
    }
}

// MARK: - Render Models (copied from PostRenderModels.swift)

struct PostRenderModel {
    let post: Post
    let enableCustomTitlePostLayout: Bool

    init(_ post: Post, enableCustomTitlePostLayout: Bool = false) {
        self.post = post
        self.enableCustomTitlePostLayout = enableCustomTitlePostLayout
    }
    
    var author: UserRenderModel? {
        post.author.map { UserRenderModel($0, enableCustomTitlePostLayout: enableCustomTitlePostLayout) }
    }

    var htmlContents: String {
        return post.innerHTML ?? ""
    }
    
    var postID: String {
        post.postID
    }
    
    var threadIndex: Int {
        return Int(post.threadIndex)
    }
    
    var postDate: Date? {
        return post.postDate
    }

    var postDateRaw: String {
        if let rawDate = (self.post as NSManagedObject).value(forKey: "postDateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return post.postDate.map { DateFormatter.postDateFormatter.string(from: $0) } ?? ""
    }
    
    var beenSeen: Bool {
        return post.beenSeen
    }
    
    var editable: Bool {
        return post.editable
    }

    var roles: String {
        guard let rolesSet = post.author?.roles as? NSSet else { return "" }
        let cssClasses = (rolesSet.allObjects as? [NSManagedObject] ?? []).compactMap { role -> String? in
            guard let name = (role as NSManagedObject).value(forKey: "name") as? String else { return nil }
            switch name {
            case "Administrator": return "role-admin"
            case "Moderator": return "role-mod"
            case "Super Moderator": return "role-supermod"
            case "IK": return "role-ik"
            case "Coder": return "role-coder"
            default: return ""
            }
        }
        return cssClasses.joined(separator: " ")
    }
    
    func visibleAvatarURL(showAvatars: Bool) -> URL? {
        guard let author = author else { return nil }
        return author.visibleAvatarURL(showAvatars: showAvatars)
    }

    func hiddenAvatarURL(showAvatars: Bool) -> URL? {
        guard let author = author else { return nil }
        return author.hiddenAvatarURL(showAvatars: showAvatars)
    }

    var customTitleHTML: String? {
        guard enableCustomTitlePostLayout else { return nil }
        return author?.customTitleHTML
    }
    
    func asDictionary(showAvatars: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "htmlContents": htmlContents,
            "postID": postID,
            "threadIndex": threadIndex,
            "beenSeen": beenSeen,
            "editable": editable,
            "postDateRaw": postDateRaw,
            "roles": roles,
        ]
        
        if let author = author {
            dict["author"] = author.asDictionary(showAvatars: showAvatars)
        }
        
        if let postDate = postDate {
            dict["postDate"] = postDate
        }
        
        let visibleAvatarURL = visibleAvatarURL(showAvatars: showAvatars)
        if let visibleAvatarURL = visibleAvatarURL {
            dict["visibleAvatarURL"] = visibleAvatarURL.absoluteString
        }
        
        let hiddenAvatarURL = hiddenAvatarURL(showAvatars: showAvatars)
        if let hiddenAvatarURL = hiddenAvatarURL {
            dict["hiddenAvatarURL"] = hiddenAvatarURL.absoluteString
        }
        
        if let customTitleHTML = customTitleHTML {
            dict["customTitleHTML"] = customTitleHTML
        }
        
        return dict
    }
}

struct UserRenderModel {
    let user: User
    let enableCustomTitlePostLayout: Bool

    init(_ user: User, enableCustomTitlePostLayout: Bool = false) {
        self.user = user
        self.enableCustomTitlePostLayout = enableCustomTitlePostLayout
    }

    var userID: String {
        user.userID
    }
    
    var username: String? {
        user.username
    }
    
    func visibleAvatarURL(showAvatars: Bool) -> URL? {
        guard showAvatars else { return nil }
        return user.avatarURL
    }

    func hiddenAvatarURL(showAvatars: Bool) -> URL? {
        guard !showAvatars else { return nil }
        return user.avatarURL
    }
    
    var customTitleHTML: String? {
        guard enableCustomTitlePostLayout else { return nil }
        return user.customTitleHTML
    }
    
    var regdate: Date? {
        return user.regdate
    }

    var regdateRaw: String {
        if let rawDate = (self.user as NSManagedObject).value(forKey: "regdateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return user.regdate.map { DateFormatter.regDateFormatter.string(from: $0) } ?? ""
    }
    
    func asDictionary(showAvatars: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "userID": userID,
            "regdateRaw": regdateRaw,
        ]
        
        if let username = username {
            dict["username"] = username
        }
        
        let visibleAvatarURL = visibleAvatarURL(showAvatars: showAvatars)
        if let visibleAvatarURL = visibleAvatarURL {
            dict["visibleAvatarURL"] = visibleAvatarURL.absoluteString
        }

        let hiddenAvatarURL = hiddenAvatarURL(showAvatars: showAvatars)
        if let hiddenAvatarURL = hiddenAvatarURL {
            dict["hiddenAvatarURL"] = hiddenAvatarURL.absoluteString
        }
        
        if let customTitleHTML = customTitleHTML {
            dict["customTitleHTML"] = customTitleHTML
        }
        
        if let regdate = regdate {
            dict["regdate"] = regdate
        }
        
        return dict
    }
}

// MARK: - Date Formatters Extension
private extension DateFormatter {
    static let postDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
    
    static let regDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

// MARK: - Post Actions Menu

/// SwiftUI Menu for post actions, styled exactly like the hamburger menu
struct PostActionsMenu: View {
    let post: Post
    let onReplyTapped: () -> Void
    let onQuoteTapped: () -> Void
    let onEditTapped: (() -> Void)?
    let onMarkReadTapped: () -> Void
    let onCopyURLTapped: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    var body: some View {
        Menu {
            // Reply action
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onReplyTapped()
            }) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            
            // Quote action
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onQuoteTapped()
            }) {
                Label("Quote", systemImage: "quote.bubble")
            }
            
            // Edit action (if editable)
            if let onEditTapped = onEditTapped {
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onEditTapped()
                }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            // Mark as read action
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onMarkReadTapped()
            }) {
                Label("Mark as Read Up To Here", systemImage: "checkmark.circle")
            }
            
            // Copy URL action
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onCopyURLTapped()
            }) {
                Label("Copy Post URL", systemImage: "doc.on.doc")
            }
        } label: {
            // Use a transparent view since the actual post-dots image is in the webview
            Rectangle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Post Actions")
    }
    
    private var toolbarTextColor: Color {
        Color(theme[uicolor: "toolbarTextColor"] ?? UIColor.systemBlue)
    }
}

// MARK: - HiddenMenuButton

private class HiddenMenuButton: UIButton {
    init() {
        super.init(frame: .zero)
        showsMenuAsPrimaryAction = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(menu: UIMenu, from rect: CGRect) {
        frame = rect
        self.menu = menu
        gestureRecognizers?.first { "\(type(of: $0))".contains("TouchDown") }?.touchesBegan([], with: .init())
    }
}


