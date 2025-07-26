//  SwiftUIRenderViewNative.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import CoreData
import Foundation
import SwiftUI
import UIKit
import WebKit
import Stencil
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIRenderViewNative")

// MARK: - Scroll Coordinator

/// Coordinates scroll actions between SwiftUI and the native render view
class RenderViewScrollCoordinator: ObservableObject {
    private var webViewCoordinator: WebViewCoordinator?
    
    func setWebViewCoordinator(_ coordinator: WebViewCoordinator) {
        self.webViewCoordinator = coordinator
    }
    
    func scrollToFractionalOffset(_ offset: CGPoint) {
        Task {
            await webViewCoordinator?.scrollToFractionalOffset(offset)
        }
    }
    
    func jumpToPost(_ postID: String) {
        Task {
            await webViewCoordinator?.jumpToPost(postID)
        }
    }
}

// MARK: - SwiftUI-Native RenderView

/// A SwiftUI-native view that renders HTML posts using WKWebView
/// This replaces the complex UIKit + UIViewRepresentable hosting system
struct SwiftUIRenderViewNative: View {
    
    // MARK: - Dependencies
    @ObservedObject var viewModel: PostsPageViewModel
    let theme: Theme
    let thread: AwfulThread
    let author: User?
    let scrollCoordinator: RenderViewScrollCoordinator?
    
    // MARK: - SwiftUI State Management
    @State private var webViewCoordinator: WebViewCoordinator?
    @State private var isLoaded = false
    @State private var currentHTML = ""
    @State private var lastRenderedPostsHash: Int = 0
    @State private var savedInteractionState: Any?
    @State private var processTerminationCount = 0
    @State private var hasRestoredContentThisSession = false
    
    // Performance monitoring removed - trust WebKit's native performance
    
    // Context menu handling is now done directly in WebViewCoordinator
    
    // MARK: - Callbacks (SwiftUI Style)
    let onPostAction: (Post, CGRect) -> Void
    let onUserAction: (Post, CGRect) -> Void
    let onContentRestored: (() -> Void)?
    // Scroll callbacks removed for optimal performance - WebKit handles scrolling natively
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorage(Settings.enableCustomTitlePostLayout) private var enableCustomTitlePostLayout
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    
    // MARK: - Body
    var body: some View {
        ZStack {
            WebViewRepresentable(
                coordinator: Binding(
                    get: { webViewCoordinator },
                    set: { webViewCoordinator = $0 }
                ),
                theme: theme,
                scrollCoordinator: scrollCoordinator,
                viewModel: viewModel,
                // Scroll callbacks removed for optimal performance
                onPostAction: onPostAction,
                onUserAction: onUserAction,
            )
            
            // Performance overlay removed - WebKit handles performance internally
        }
        .onAppear {
            setupWebView()
        }
        .onChange(of: webViewCoordinator) { coordinator in
            // Set up the process termination handler when coordinator becomes available
            if let coordinator = coordinator {
                logger.debug("🔧 Setting process termination handler on coordinator")
                coordinator.setProcessTerminationHandler {
                    await handleWebViewProcessTermination()
                }
            }
        }
        .onDisappear {
            Task {
                await saveWebViewState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            Task {
                await saveWebViewState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            logger.debug("📲 SwiftUIRenderViewNative received willEnterForegroundNotification")
            Task {
                // Short delay to let navigation restoration complete first
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                await checkIfWebViewNeedsReload()
            }
        }
        .onChange(of: viewModel.posts) { posts in
            // Critical: Only render posts when they actually change
            if !posts.isEmpty {
                Task {
                    await renderPosts(posts)
                }
            }
        }
        .onChange(of: viewModel.currentPage) { newPage in
            // Page changes are handled by navigation restoration system
            logger.debug("📄 Page changed to \(String(describing: newPage))")
        }
        .task {
            // Critical: Initial render when view appears
            if !viewModel.posts.isEmpty {
                await renderPosts(viewModel.posts)
            }
        }
        // Triple tap gesture removed - trust WebKit's performance
    }
    
    // MARK: - Setup & Rendering
    
    private func setupWebView() {
        logger.debug("Setting up SwiftUI-native web view")
        // WebView setup is handled by the coordinator
        
        // Set the process termination handler in the coordinator once it's created
        DispatchQueue.main.async {
            self.webViewCoordinator?.setProcessTerminationHandler {
                await self.handleWebViewProcessTermination()
            }
        }
    }
    
    // MARK: - State Preservation
    
    @MainActor
    private func saveWebViewState() async {
        guard let coordinator = webViewCoordinator else { return }
        
        logger.debug("💾 Saving WebView state before backgrounding")
        
        // Simple state saving - no complex verification needed since we use simple re-rendering approach
        savedInteractionState = coordinator.webView.interactionState
        logger.debug("✅ Saved interaction state")
    }
    
    @MainActor
    private func checkIfWebViewNeedsReload() async {
        logger.debug("🔍 Checking if WebView needs reload for coordination with SceneStorage navigation")
        
        // Wait a brief moment for SceneStorage navigation restoration to complete first
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Only proceed if we can evaluate JavaScript (WebView is loaded)
        guard let coordinator = webViewCoordinator, coordinator.webView.isLoading == false else {
            logger.debug("🔍 WebView is still loading, skipping health check")
            return
        }
        
        // Quick content check to see if we need restoration
        do {
            let postCount = try await coordinator.webView.eval("document.querySelectorAll('.postbody').length")
            let hasContent = (postCount as? Int ?? 0) > 0
            
            if !hasContent {
                logger.info("🔄 WebView needs content restoration after SceneStorage navigation restoration")
                if let state = savedInteractionState {
                    await restoreFromSavedState(state)
                } else {
                    logger.debug("📄 No saved interaction state, re-rendering posts")
                    // Re-render the current posts if we don't have saved state
                    await renderPosts(viewModel.posts)
                }
            } else {
                let postCountValue = postCount as? Int ?? 0
                logger.debug("✅ WebView content is healthy (\(postCountValue) posts), no restoration needed")
                
                // CRITICAL: Even when content is already healthy, notify coordination system
                // This prevents SwiftUIPostsPageView from triggering a fresh page load
                onContentRestored?()
            }
        } catch {
            logger.warning("⚠️ Failed to check WebView content, attempting restoration: \(error)")
            if let state = savedInteractionState {
                await restoreFromSavedState(state)
            } else {
                await renderPosts(viewModel.posts)
            }
        }
    }
    
    @MainActor
    private func handleWebViewProcessTermination() async {
        processTerminationCount += 1
        logger.error("🚨 WebView process terminated - immediately re-rendering (count: \(processTerminationCount))")
        
        guard processTerminationCount <= 3 else {
            logger.error("❌ Too many restoration attempts, giving up")
            return
        }
        
        // Simple approach like UIKit: immediately re-render the current posts
        // No delays, no complex state preservation - just re-render the current content
        // Force a re-render by resetting the hash
        lastRenderedPostsHash = 0
        await renderPosts(viewModel.posts)
    }
    
    @MainActor
    private func restoreFromSavedState(_ state: Any) async {
        guard let coordinator = webViewCoordinator else { return }
        
        logger.debug("🔄 Restoring WebView from saved interaction state")
        
        // First reload the HTML content
        await coordinator.loadHTML(currentHTML, baseURL: baseURL)
        
        // Wait for the content to load before restoring interaction state
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            do {
                let readyState = try await coordinator.webView.eval("document.readyState")
                if let readyStateString = readyState as? String, readyStateString == "complete" {
                    // Content is ready, now restore interaction state
                    coordinator.webView.interactionState = state
                    logger.debug("✅ Successfully restored WebView from saved state after \(attempts + 1) attempts")
                    return
                }
            } catch {
                logger.warning("⚠️ Error checking ready state during restoration: \(error)")
            }
            
            attempts += 1
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        }
        
        logger.warning("⚠️ Restoration timeout - proceeding with state restoration anyway")
        coordinator.webView.interactionState = state
    }
    
    // Re-rendering method removed - using direct renderPosts call for simplicity
    
    @MainActor
    private func renderPosts(_ posts: [Post]) async {
        guard let coordinator = webViewCoordinator else { return }
        
        // Create a hash to avoid unnecessary re-renders (same as original system)
        let currentPostsHash = posts.map { $0.postID }.joined().hashValue
        guard currentPostsHash != lastRenderedPostsHash else {
            logger.debug("Skipping render - already rendered these \(posts.count) posts")
            return
        }
        
        logger.debug("🔄 Rendering \(posts.count) posts")
        lastRenderedPostsHash = currentPostsHash
        
        // Generate HTML - trust Swift's task scheduling
        do {
            let html = try generateHTML(for: posts)
            currentHTML = html
        } catch {
            logger.error("HTML generation failed: \(error)")
            return
        }
        
        // Load HTML - WebKit handles this efficiently
        await coordinator.loadHTML(currentHTML, baseURL: baseURL)
        
        // Update posts in coordinator for message handling
        coordinator.updatePosts(posts)
        isLoaded = true
        
        // Save the current state after successful rendering
        await saveWebViewState()
        
        logger.debug("Posts rendering completed")
    }
    
    @MainActor
    private func updateTheme() async {
        // Re-render with new theme
        await renderPosts(viewModel.posts)
    }
    
    // MARK: - HTML Generation
    
    private func generateHTML(for posts: [Post]) throws -> String {
        // Use the same render context and Stencil template system as the original
        let context = NativeRenderContext(
            advertisementHTML: nil, // No ads in this simplified version
            author: author,
            firstUnreadPost: viewModel.firstUnreadPost,
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
        
        // Determine if we're on the last page for end message
        let isLastPage: Bool
        if let page = viewModel.currentPage {
            switch page {
            case .last:
                isLastPage = true
            case .specific(let n):
                isLastPage = n == viewModel.numberOfPages
            case .nextUnread:
                isLastPage = false
            }
        } else {
            isLastPage = false
        }
        contextDict["endMessage"] = isLastPage && author == nil
        
        // Use the existing Stencil environment
        return try StencilEnvironment.shared.renderTemplate(.postsView, context: contextDict)
    }
    
    private var baseURL: URL? {
        // Use the same base URL as the original system
        ForumsClient.shared.baseURL
    }
    
    // MARK: - Public API (SwiftUI Style)
    
    /// Scrolls to a fractional position in the content
    func scrollToFractionalOffset(_ offset: CGPoint) {
        Task {
            await webViewCoordinator?.scrollToFractionalOffset(offset)
        }
    }
    
    /// Jumps to a specific post by ID
    func jumpToPost(identifiedBy postID: String) {
        Task {
            await webViewCoordinator?.jumpToPost(postID)
        }
    }
    
    // Context menus are now handled directly by WebViewCoordinator
    
    // MARK: - Performance API
    
    // Performance metrics removed - WebKit provides optimal performance natively
}

// MARK: - Minimal WebView Wrapper

/// Minimal UIViewRepresentable wrapper around WKWebView
/// This replaces the complex 1,972-line hosting system with ~200 lines
struct WebViewRepresentable: UIViewRepresentable {
    
    @Binding var coordinator: WebViewCoordinator?
    let theme: Theme
    let scrollCoordinator: RenderViewScrollCoordinator?
    let viewModel: PostsPageViewModel
    // Scroll callbacks removed for optimal performance
    var onPostAction: ((Post, CGRect) -> Void)?
    var onUserAction: ((Post, CGRect) -> Void)?
    
    func makeUIView(context: UIViewRepresentableContext<WebViewRepresentable>) -> WKWebView {
        let config = createWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Disable WebKit's navigation gestures to prevent conflicts (research recommendation)
        webView.allowsBackForwardNavigationGestures = false
        
        // Configure webview appearance with performance optimizations
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.decelerationRate = .normal
        webView.allowsBackForwardNavigationGestures = false
        
        // Basic scroll view settings - trust WebKit's defaults
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Use WebKit's default rendering settings
        
        // Keep basic image loading optimization (doesn't interfere with scroll)
        NetworkOptimizer.shared.optimizeImageLoading(for: webView)
        
        // Create coordinator
        let webViewCoordinator = WebViewCoordinator(
            webView: webView,
            theme: theme,
            // Scroll callbacks removed for optimal performance
            onPostAction: onPostAction,
            onUserAction: onUserAction,
            viewModel: viewModel,
            onProcessTermination: nil // Will be set after coordinator is assigned
        )
        
        webView.navigationDelegate = webViewCoordinator
        // Set scroll delegate for basic position tracking
        webView.scrollView.delegate = webViewCoordinator
        
        // Set coordinator
        DispatchQueue.main.async {
            coordinator = webViewCoordinator
            // Connect to scroll coordinator for external scroll control
            scrollCoordinator?.setWebViewCoordinator(webViewCoordinator)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: UIViewRepresentableContext<WebViewRepresentable>) {
        // Update theme colors if needed
        webView.scrollView.backgroundColor = theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground
    }
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let bundle = Bundle.main
        
        // Use WebKit's default settings for best performance
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        
        // Trust WebKit's automatic process management
        
        // Add JavaScript files with error handling
        do {
            if let url = bundle.url(forResource: "RenderView.js", withExtension: nil) {
                let script = try String(contentsOf: url)
                configuration.userContentController.addUserScript(
                    WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                )
            }
            
            if let url = bundle.url(forResource: "RenderView-AllFrames.js", withExtension: nil) {
                let script = try String(contentsOf: url)
                configuration.userContentController.addUserScript(
                    WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
                )
            }
        } catch {
            logger.error("Failed to load JavaScript files: \(error)")
        }
        
        // Set URL scheme handlers with error handling
        configuration.setURLSchemeHandler(ImageURLProtocol(), forURLScheme: ImageURLProtocol.scheme)
        configuration.setURLSchemeHandler(ResourceURLProtocol(), forURLScheme: ResourceURLProtocol.scheme)
        
        // WebKit handles network optimizations internally
        
        return configuration
    }
}

// MARK: - WebView Coordinator

/// Handles WebView delegation and coordination
/// This replaces the complex RenderViewContainer with clean SwiftUI-style coordination
class WebViewCoordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
    
    // Hidden button that shows context menus (same approach as SwiftUI version)
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
    
    let webView: WKWebView
    private let theme: Theme
    // Scroll callbacks removed for optimal performance
    
    // Context menu callbacks
    private var onPostAction: ((Post, CGRect) -> Void)?
    private var onUserAction: ((Post, CGRect) -> Void)?
    private var posts: [Post] = []
    private var viewModel: PostsPageViewModel?
    private var onProcessTermination: (() async -> Void)?
    
    // Context menu implementation
    private lazy var hiddenMenuButton: HiddenMenuButton = {
        let button = HiddenMenuButton()
        webView.addSubview(button)
        return button
    }()
    
    // Simplified scroll tracking - trust WebKit's native performance
    private var lastScrollOffset: CGFloat = 0
    
    init(
        webView: WKWebView,
        theme: Theme,
        // Scroll callbacks removed for optimal performance
        onPostAction: ((Post, CGRect) -> Void)?,
        onUserAction: ((Post, CGRect) -> Void)?,
        viewModel: PostsPageViewModel?,
        onProcessTermination: (() async -> Void)?
    ) {
        self.webView = webView
        self.theme = theme
        // Scroll callbacks removed for optimal performance
        self.onPostAction = onPostAction
        self.onUserAction = onUserAction
        self.viewModel = viewModel
        self.onProcessTermination = onProcessTermination
        super.init()
        
        Task {
            await setupMessageHandlers()
        }
        
        // Performance monitoring removed - WebKit handles this natively
    }
    
    // MARK: - HTML Loading
    
    @MainActor
    func loadHTML(_ html: String, baseURL: URL?) async {
        // Trust WebKit to handle HTML loading efficiently
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    
    // MARK: - Scroll Control
    
    @MainActor
    func scrollToFractionalOffset(_ offset: CGPoint) async {
        do {
            _ = try await webView.eval("""
                window.scrollTo(
                    document.body.scrollWidth * \(offset.x),
                    document.body.scrollHeight * \(offset.y));
                """)
        } catch {
            logger.error("Error scrolling: \(error)")
        }
    }
    
    @MainActor
    func jumpToPost(_ postID: String) async {
        let escapedPostID: String
        do {
            escapedPostID = try escapeForEval(postID)
        } catch {
            logger.error("Could not JSON-escape the post ID: \(error)")
            return
        }
        
        do {
            _ = try await webView.eval("if (window.Awful) Awful.jumpToPostWithID(\(escapedPostID))")
            logger.debug("📜 Successfully called Awful.jumpToPostWithID for post \(postID)")
        } catch {
            logger.error("Could not evaluate jumpToPostWithID: \(error)")
        }
    }
    
    // MARK: - Quote Link Handling
    
    @MainActor
    private func handleQuoteLink(postID: String, updateSeen: AwfulRoute.UpdateSeen, url: URL) async {
        logger.debug("🎯 Handling quote link for post \(postID)")
        
        // Check if the post is on the current page
        if posts.contains(where: { $0.postID == postID }) {
            logger.debug("✅ Post \(postID) found on current page - scrolling to it")
            await jumpToPost(postID)
            return
        }
        
        // Post is not on current page - need to determine if it's in the same thread
        // Check if this is a same-thread quote by looking at the URL structure
        guard let viewModel = viewModel else {
            logger.error("❌ No viewModel available for quote link handling")
            AppDelegate.instance.open(route: .post(id: postID, updateSeen))
            return
        }
        
        // Extract thread ID from the URL to check if it's the same thread
        let currentThreadID = viewModel.thread.threadID
        
        // Check if the URL contains a threadid parameter (different thread) or just postid (same thread)
        if let threadID = url.valueForFirstQueryItem(named: "threadid"), !threadID.isEmpty {
            if threadID == currentThreadID {
                logger.debug("📄 Post \(postID) is in same thread but different page - loading in webview")
                await loadPostInWebView(postID: postID, threadID: threadID, updateSeen: updateSeen)
            } else {
                logger.debug("🔀 Post \(postID) is in different thread \(threadID) - using SwiftUI navigation")
                AppDelegate.instance.open(route: .post(id: postID, updateSeen))
            }
        } else {
            // No threadid in URL means it's a goto=post&postid= link, which is same thread
            logger.debug("📄 Quote link with no threadid - loading in webview for same thread")
            await loadPostInWebView(postID: postID, threadID: currentThreadID, updateSeen: updateSeen)
        }
    }
    
    @MainActor
    private func loadPostInWebView(postID: String, threadID: String, updateSeen: AwfulRoute.UpdateSeen) async {
        logger.debug("🔄 Loading post \(postID) in current webview for thread \(threadID)")
        
        guard let viewModel = viewModel else {
            logger.error("❌ No viewModel available")
            return
        }
        
        // First, check if the post exists in Core Data to get its page number
        guard let context = AppDelegate.instance?.managedObjectContext else {
            logger.error("❌ No Core Data context available")
            return
        }
        
        let request = NSFetchRequest<Post>(entityName: Post.entityName)
        request.predicate = NSPredicate(format: "postID == %@", postID)
        request.fetchLimit = 1
        
        do {
            let posts = try context.fetch(request)
            
            if let post = posts.first, 
               let thread = post.thread,
               thread.threadID == threadID,
               post.page > 0 {
                // Post found in cache and is in the same thread
                let targetPage = post.page
                logger.debug("✅ Found post \(postID) in cache on page \(targetPage)")
                
                // Check if we're already on the correct page
                if case .specific(let currentPageNum) = viewModel.currentPage, currentPageNum == targetPage {
                    logger.debug("📄 Already on correct page \(targetPage), just scrolling to post")
                    await jumpToPost(postID)
                } else {
                    logger.debug("📄 Loading page \(targetPage) and will scroll to post \(postID)")
                    // Set the jump target before loading the page
                    viewModel.jumpToPostID = postID
                    // Load the correct page in the current webview
                    viewModel.loadPage(.specific(targetPage))
                }
            } else {
                // Post not found in cache or not in same thread, need to make network request
                logger.debug("🌐 Post \(postID) not found in cache, making network request")
                await loadPostViaNetworkRequest(postID: postID, updateSeen: updateSeen)
            }
        } catch {
            logger.error("❌ Error fetching post from Core Data: \(error)")
            await loadPostViaNetworkRequest(postID: postID, updateSeen: updateSeen)
        }
    }
    
    @MainActor
    private func loadPostViaNetworkRequest(postID: String, updateSeen: AwfulRoute.UpdateSeen) async {
        logger.debug("🌐 Making network request to locate post \(postID)")
        
        guard let viewModel = viewModel else {
            logger.error("❌ No viewModel available for network request")
            return
        }
        
        let updateLastRead = (updateSeen == .seen)
        
        do {
            // Use ForumsClient to locate the post (this will scrape and cache it)
            let (foundPost, page) = try await ForumsClient.shared.locatePost(id: postID, updateLastReadPost: updateLastRead)
            
            if let thread = foundPost.thread,
               thread.threadID == viewModel.thread.threadID {
                // Post is in same thread, load the page and scroll to it
                logger.debug("✅ Network request found post \(postID) on page \(String(describing: page))")
                viewModel.jumpToPostID = postID
                viewModel.loadPage(page)
            } else {
                // Post is in a different thread, use SwiftUI navigation
                logger.debug("🔀 Post \(postID) is in different thread, using SwiftUI navigation")
                AppDelegate.instance.open(route: .post(id: postID, updateSeen))
            }
        } catch {
            logger.error("❌ Network request failed for post \(postID): \(error)")
            // Fallback to SwiftUI navigation
            AppDelegate.instance.open(route: .post(id: postID, updateSeen))
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Only intercept actual link taps, allow everything else (like initial page loads)
        guard navigationAction.navigationType == .linkActivated else {
            return decisionHandler(.allow)
        }
        
        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }
        
        // Cancel the navigation - we'll handle it ourselves
        decisionHandler(.cancel)
        
        logger.debug("🔗 Link tapped: \(url)")
        
        // Try to handle as internal Awful route first
        if let route = try? AwfulRoute(url) {
            logger.debug("📱 Parsed as internal route: \(route)")
            
            // Special handling for quote links (post routes)
            if case .post(let postID, let updateSeen) = route {
                Task { @MainActor in
                    await handleQuoteLink(postID: postID, updateSeen: updateSeen, url: url)
                }
                return
            }
            
            // For non-quote routes, use normal SwiftUI navigation
            logger.debug("📱 Opening non-quote route with SwiftUI navigation: \(route)")
            AppDelegate.instance.open(route: route)
            return
        }
        
        // Handle external URLs
        if url.opensInBrowser {
            logger.debug("🌐 Opening external URL in browser: \(url)")
            if let parentVC = findParentViewController() {
                URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: parentVC)
            } else {
                UIApplication.shared.open(url)
            }
        } else {
            logger.debug("📱 Opening URL with system: \(url)")
            UIApplication.shared.open(url)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.debug("🌐 WebView finished loading - JavaScript should be ready")
        
        // Test JavaScript availability asynchronously
        Task { @MainActor in
            do {
                let result = try await webView.eval("typeof window.webkit !== 'undefined' && typeof window.webkit.messageHandlers !== 'undefined'")
                logger.debug("📱 JavaScript webkit availability: \(String(describing: result))")
                
                let awfulResult = try await webView.eval("typeof window.Awful !== 'undefined'")
                logger.debug("👹 Awful JavaScript object availability: \(String(describing: awfulResult))")
            } catch {
                logger.error("❌ Failed to test JavaScript: \(error)")
            }
        }
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        logger.error("🚨 WebView process terminated - triggering restoration")
        
        // Call the termination handler
        Task { @MainActor in
            await onProcessTermination?()
        }
    }
    
    // MARK: - UIScrollViewDelegate (Simplified - Trust WebKit)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        
        // All scroll callbacks removed for optimal performance - trust WebKit
        lastScrollOffset = currentOffset
    }
    
    // MARK: - Performance Tracking Removed - WebKit Handles This Natively
    
    // MARK: - Message Handling Setup
    
    @MainActor
    private func setupMessageHandlers() async {
        // Register for JavaScript messages from RenderView.js
        webView.configuration.userContentController.add(self, name: "didTapPostActionButton")
        webView.configuration.userContentController.add(self, name: "didTapAuthorHeader")
        webView.configuration.userContentController.add(self, name: "didFinishLoadingTweets")
        webView.configuration.userContentController.add(self, name: "fetchOEmbedFragment")
        webView.configuration.userContentController.add(self, name: "didRender")
        
        logger.debug("🔧 Message handlers registered: didTapPostActionButton, didTapAuthorHeader, didFinishLoadingTweets, fetchOEmbedFragment, didRender")
    }
    
    @MainActor
    func updatePosts(_ posts: [Post]) {
        self.posts = posts
    }
    
    func setProcessTerminationHandler(_ handler: @escaping () async -> Void) {
        logger.debug("🔧 Process termination handler set on WebViewCoordinator")
        self.onProcessTermination = handler
    }
    
    // MARK: - WKScriptMessageHandler
    
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor in
            await handleScriptMessage(message)
        }
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) async {
        logger.debug("📨 Received JavaScript message: \(message.name) with body: \(String(describing: message.body))")
        
        switch message.name {
        case "didTapPostActionButton":
            logger.debug("👆 Handling post action button tap")
            await handlePostActionButtonTap(message)
            
        case "didTapAuthorHeader":
            logger.debug("👤 Handling author header tap")
            await handleAuthorHeaderTap(message)
            
        case "didFinishLoadingTweets":
            logger.debug("🐦 Tweets finished loading")
            
        case "fetchOEmbedFragment":
            logger.debug("🔗 Handling OEmbed request")
            await handleOEmbedRequest(message)
            
        case "didRender":
            logger.debug("✅ JavaScript rendering completed")
            
        default:
            logger.warning("❓ Unhandled script message: \(message.name)")
        }
    }
    
    private func handlePostActionButtonTap(_ message: WKScriptMessage) async {
        logger.debug("🔍 Post action button - parsing message body")
        guard let body = message.body as? [String: Any],
              let frameDict = body["frame"] as? [String: Double],
              let postIndex = body["postIndex"] as? Int,
              postIndex < self.posts.count,
              let viewModel = self.viewModel else {
            logger.error("❌ Invalid post action button message: \(String(describing: message.body))")
            logger.error("   - Body type: \(type(of: message.body))")
            logger.error("   - Posts count: \(self.posts.count)")
            logger.error("   - ViewModel available: \(self.viewModel != nil)")
            return
        }
        
        logger.debug("✅ Post action button - valid message: postIndex=\(postIndex), frame=\(frameDict)")
        
        let frame = CGRect(
            x: frameDict["x"] ?? 0,
            y: frameDict["y"] ?? 0,
            width: frameDict["width"] ?? 0,
            height: frameDict["height"] ?? 0
        )
        
        let post = self.posts[postIndex]
        
        // Present context menu using UIKit
        presentPostContextMenu(for: post, at: frame, viewModel: viewModel)
        
        // Call original callback for compatibility
        onPostAction?(post, frame)
    }
    
    private func handleAuthorHeaderTap(_ message: WKScriptMessage) async {
        logger.debug("🔍 Author header - parsing message body")
        guard let body = message.body as? [String: Any],
              let frameDict = body["frame"] as? [String: Double],
              let postIndex = body["postIndex"] as? Int,
              postIndex < self.posts.count,
              let post = self.posts[safe: postIndex],
              let author = post.author,
              let viewModel = self.viewModel else {
            logger.error("❌ Invalid author header message: \(String(describing: message.body))")
            logger.error("   - Body type: \(type(of: message.body))")
            logger.error("   - Posts count: \(self.posts.count)")
            if let bodyDict = message.body as? [String: Any], let postIndex = bodyDict["postIndex"] as? Int, postIndex < self.posts.count {
                logger.error("   - Post has author: \(self.posts[postIndex].author != nil)")
            }
            logger.error("   - ViewModel available: \(self.viewModel != nil)")
            return
        }
        
        logger.debug("✅ Author header - valid message: postIndex=\(postIndex), author=\(author.username ?? "unknown"), frame=\(frameDict)")
        
        let frame = CGRect(
            x: frameDict["x"] ?? 0,
            y: frameDict["y"] ?? 0,
            width: frameDict["width"] ?? 0,
            height: frameDict["height"] ?? 0
        )
        
        // Present context menu using UIKit
        presentUserContextMenu(for: post, author: author, at: frame, viewModel: viewModel)
        
        // Call original callback for compatibility
        onUserAction?(post, frame)
    }
    
    private func handleOEmbedRequest(_ message: WKScriptMessage) async {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let urlString = body["url"] as? String,
              let url = URL(string: urlString) else {
            logger.error("Invalid OEmbed request: \(String(describing: message.body))")
            return
        }
        
        // TODO: Implement OEmbed fetching similar to original system
        // For now, just log the request
        logger.debug("OEmbed request for \(url) with id \(id)")
    }
    
    deinit {
        // Cleanup simplified - WebKit handles performance internally
    }
    
    // MARK: - Context Menu Presentation
    
    private func presentPostContextMenu(for post: Post, at frame: CGRect, viewModel: PostsPageViewModel) {
        logger.debug("🎯 Presenting post context menu for post \(post.postID) at frame \(String(describing: frame))")
        
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        var actions: [UIAction] = []
        
        // Quote action (first)
        actions.append(UIAction(title: "Quote", image: UIImage(named: "quote-post")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            viewModel.quotePost(post) { workspace in
                Task { @MainActor in
                    // TODO: Present reply workspace via proper delegate/callback
                    logger.debug("Quote post workspace created for post \(post.postID)")
                }
            }
        })
        
        // Mark as last read action (second, renamed)
        actions.append(UIAction(title: "Mark as last read", image: UIImage(named: "mark-read-up-to-here")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            viewModel.markAsReadUpTo(post)
        })
        
        // Share action (third)
        actions.append(UIAction(title: "Share", image: UIImage(named: "share")?.withRenderingMode(.alwaysTemplate)) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentSharePost(post)
        })
        
        // Report action (fourth, using custom icon)
        actions.append(UIAction(title: "Report", image: UIImage(named: "rap-sheet")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentReportPost(post)
        })
        
        let menu = UIMenu(title: "", children: actions)
        hiddenMenuButton.show(menu: menu, from: frame)
        logger.debug("📋 Post context menu shown using HiddenMenuButton")
    }
    
    private func presentUserContextMenu(for post: Post, author: User, at frame: CGRect, viewModel: PostsPageViewModel) {
        logger.debug("🎯 Presenting user context menu for \(author.username ?? "unknown") at frame \(String(describing: frame))")
        
        let enableHaptics = UserDefaults.standard.defaultingValue(for: Settings.enableHaptics)
        
        var actions: [UIAction] = []
        
        // Profile action
        actions.append(UIAction(title: "Profile", image: UIImage(named: "user-profile")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentUserProfile(userID: author.userID)
        })
        
        // Private message action (if available)
        if author.canReceivePrivateMessages == true {
            actions.append(UIAction(title: "Send Private Message", image: UIImage(named: "send-private-message")) { _ in
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                AppDelegate.instance.mainCoordinator?.presentPrivateMessageComposer(for: author)
            })
        }
        
        // Filter posts action
        actions.append(UIAction(title: "User's Posts in This Thread", image: UIImage(named: "single-users-posts")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.navigateToThread(viewModel.thread, page: .specific(1), author: author)
        })
        
        // Rap sheet action
        actions.append(UIAction(title: "Rap Sheet", image: UIImage(named: "rap-sheet")) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            AppDelegate.instance.mainCoordinator?.presentRapSheet(userID: author.userID)
        })
        
        let menu = UIMenu(title: author.username ?? "Unknown User", children: actions)
        hiddenMenuButton.show(menu: menu, from: frame)
        logger.debug("📋 User context menu shown using HiddenMenuButton")
    }
    
    private func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = webView
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
}

// MARK: - Supporting Types

/// Context for HTML generation (matches original RenderContext structure)
private struct NativeRenderContext {
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
            "advertisementHTML": advertisementHTML ?? "",
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
            if let ghostUrl = Bundle.main.url(forResource: "ghost60", withExtension: "json") {
                do {
                    let ghostData = try Data(contentsOf: ghostUrl)
                    context["ghostJsonData"] = String(data: ghostData, encoding: .utf8) as Any
                } catch {
                    logger.error("Failed to load ghost JSON: \(error)")
                }
            }
        }
        
        if let author = author {
            context["author"] = UserRenderModel(author, enableCustomTitlePostLayout: enableCustomTitlePostLayout).asDictionary(showAvatars: showAvatars)
        }
        
        return context
    }
}

// MARK: - Render Models
// PostRenderModel and UserRenderModel are imported from PostRenderModels.swift

// MARK: - Extensions

extension WKWebView {
    func eval(_ javascript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javascript) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

// MARK: - Helper Functions

private func escapeForEval(_ s: String) throws -> String {
    return String(data: try JSONEncoder().encode([s]), encoding: .utf8)! + "[0]"
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
