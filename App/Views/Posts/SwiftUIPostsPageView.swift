//  SwiftUIPostsPageView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import SwiftUI
import UIKit
import WebKit
import Lottie
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIPostsPageView")


struct IdentifiableReplyWorkspace: Identifiable {
    let id = UUID()
    let workspace: ReplyWorkspace
}

struct SwiftUIPostsPageView: View {
    let thread: AwfulThread
    let author: User?
    let coordinator: AnyObject?
    
    @StateObject private var viewModel: PostsPageViewModel
    @SwiftUI.Environment(\.theme) private var globalTheme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Forum-Specific Theme
    private var theme: Theme {
        guard let forum = thread.forum, !forum.forumID.isEmpty else {
            return Theme.defaultTheme()
        }
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    @FoilDefaultStorage(Settings.postsImmersiveMode) private var postsImmersiveMode
    
    // MARK: - State Management
    @StateObject private var scrollState = ScrollStateManager()
    @State private var isLoadingSpinnerVisible: Bool = false
    @State private var arrowPullProgress: CGFloat = 0.0
    @State private var wasArrowTriggered: Bool = false
    @State private var showingSettings = false
    @State private var showingPagePicker = false
    @State private var messageViewController: MessageComposeViewController?
    @State private var replyWorkspace: IdentifiableReplyWorkspace?
    @State private var currentScrollFraction: CGFloat = 0.0
    @State private var pendingScrollFraction: CGFloat?
    
    // MARK: - State
    @State private var specificPageToLoad: ThreadPage?
    @State private var pendingJumpToPostID: String?
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage? = nil, coordinator: AnyObject? = nil, scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
        
        // Store scroll fraction for restoration after posts are loaded
        self.pendingScrollFraction = scrollFraction
        
        // Store specific page to load in onAppear
        self._specificPageToLoad = State(initialValue: page)
        
        // Store jumpToPostID to set after view appears to avoid StateObject creation issues
        self._pendingJumpToPostID = State(initialValue: jumpToPostID)
    }
    
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage = .specific(1), coordinator: AnyObject? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
    }
    
    // MARK: - Body
    var body: some View {
        mainContentView
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(postsImmersiveMode ? !scrollState.isTopBarVisible : false)
            .onChange(of: scrollState.isTopBarVisible) { newValue in
                // Top bar visibility changed
            }
            .navigationTitle(thread.title ?? "Thread")
            .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
            .overlay(alignment: .top) {
                topSubToolbar
            }
            .overlay(alignment: .bottom) {
                bottomOverlays
            }
            .overlay(alignment: .center) {
                loadingOverlay
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.replyToPost { workspace in
                            replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                        }
                    }) {
                        Image("compose")
                            .renderingMode(.template)
                    }
                    .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                }
            }
            .onAppear {
                handleViewAppear()
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                isLoadingSpinnerVisible = isLoading
            }
            .onDisappear {
                handleViewDisappear()
            }
            .sheet(item: $replyWorkspace) { identifiableWorkspace in
                replyWorkspaceSheet(identifiableWorkspace)
            }
            .sheet(isPresented: $showingSettings) {
                PostsPageSettingsView()
                    .environment(\.theme, theme)
            }
            .onChange(of: viewModel.scrollToFraction) { fraction in
                handleScrollToFraction(fraction)
            }
            .onChange(of: viewModel.posts) { posts in
                handlePostsChanged(posts)
            }
    }
    
    // MARK: - Main Content
    private var mainContentView: some View {
        ZStack {
            // Full-screen background that extends into all safe areas
            Color(theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground)
                .ignoresSafeArea(postsImmersiveMode ? .all : .container)
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                // Loading state
                loadingView
            } else {
                // Main content - webview
                mainRenderView
            }
        }
    }
    
    // MARK: - Render View
    private var mainRenderView: some View {
        ZStack(alignment: .bottom) {
            SwiftUIRenderView(
                viewModel: viewModel,
                theme: theme,
                onPostAction: handlePostAction,
                onUserAction: handleUserAction,
                onScrollChanged: { isScrollingUp in
                    // Handle scroll for bar visibility with spring animation for natural feel
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        scrollState.handleScrollChange(isScrollingUp: isScrollingUp)
                    }
                },
                onPullChanged: { fraction in
                    // Update both frog and arrow pull progress
                    scrollState.handlePullChanged(fraction: fraction, isLastPage: viewModel.isLastPage)
                    // Only log significant progress changes
                    if abs(fraction - arrowPullProgress) > 0.1 {
                        print("🔄 SwiftUIPostsPageView: Pull progress: \(String(format: "%.2f", fraction))")
                    }
                    
                    // Track when arrow becomes triggered
                    if fraction >= 0.8 && !wasArrowTriggered {
                        wasArrowTriggered = true
                        print("🔄 SwiftUIPostsPageView: Arrow became triggered!")
                    } else if fraction < 0.3 {
                        wasArrowTriggered = false
                    }
                    
                    arrowPullProgress = fraction
                },
                onRefreshTriggered: {
                    // This will NOT be called anymore for pull-for-next
                    // The arrow control handles its own triggering
                    viewModel.refresh() // Only for other refresh scenarios
                },
                onScrollPositionChanged: { offset, contentHeight, viewHeight in
                    // Update scroll position state with throttling
                    scrollState.handleScrollPositionChanged(offset: offset, contentHeight: contentHeight, viewHeight: viewHeight)
                    
                    // Track current scroll fraction for state restoration
                    if contentHeight > 0 {
                        currentScrollFraction = (offset + viewHeight/2) / contentHeight
                    }
                },
                onDragEnded: { willDecelerate in
                    // Notify arrow control about drag end for release detection
                    if pullForNext && frogAndGhostEnabled && wasArrowTriggered {
                        print("🔄 SwiftUIPostsPageView: Drag ended while arrow was triggered! Firing navigation.")
                        // Reset state and navigate
                        wasArrowTriggered = false
                        arrowPullProgress = 0.0
                        // Set pending scroll fraction to scroll to top of new page
                        pendingScrollFraction = 0.0
                        viewModel.goToNextPage()
                    }
                },
                replyWorkspace: $replyWorkspace,
                topInset: scrollState.topInset,
                bottomInset: scrollState.bottomInset,
                isImmersiveMode: postsImmersiveMode
            )
            .id("render-view-\(viewModel.thread.threadID)")
            .ignoresSafeArea(postsImmersiveMode ? .all : .container)
            
            // Arrow pull control - positioned in overscroll area below content
            if pullForNext && frogAndGhostEnabled && arrowPullProgress > 0 {
                SwiftUIArrowPullControl(
                    theme: theme,
                    pullProgress: arrowPullProgress,
                    isVisible: true,
                    onRefreshTriggered: {
                        print("🔄 SwiftUIPostsPageView: Arrow control onRefreshTriggered called")
                        // Reset scroll state before navigating
                        arrowPullProgress = 0.0
                        pendingScrollFraction = nil // Clear any pending scroll restoration
                        viewModel.goToNextPage()
                    }
                )
                .offset(y: 40) // Position further below the content for better spacing
            }
        }
    }
    
    // MARK: - Top Subtoolbar
    private var topSubToolbar: some View {
        Group {
            if scrollState.isSubToolbarVisible {
                VStack(spacing: 0) {
                    HStack {
                        Button("Previous Posts") {
                            // TODO: Implement previous posts functionality
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        Button(thread.forum?.name ?? "Parent Forum") {
                            handleGoToParentForum()
                        }
                        .font(.caption.weight(.medium))
                        
                        Spacer()
                        
                        Button("Scroll To End") {
                            // TODO: Implement scroll to end functionality
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(theme[uicolor: "tabBarBackgroundColor"] ?? UIColor.systemBackground))
                    .foregroundColor(Color(theme[uicolor: "toolbarTextColor"] ?? UIColor.systemBlue))
                }
                .padding(.top, postsImmersiveMode ? 0 : 0)
                .transition(.opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: scrollState.isSubToolbarVisible)
            }
        }
    }
    
    // MARK: - Bottom Overlays
    private var bottomOverlays: some View {
        VStack(spacing: 0) {
            // Bottom toolbar overlay
            if !postsImmersiveMode || scrollState.isBottomBarVisible {
                PostsToolbarContainer(
                    thread: thread,
                    author: author,
                    page: viewModel.currentPage,
                    numberOfPages: viewModel.numberOfPages,
                    isLoadingViewVisible: isLoadingSpinnerVisible,
                    onSettingsTapped: {
                        showingSettings = true
                    },
                    onBackTapped: {
                        viewModel.goToPreviousPage()
                    },
                    onForwardTapped: {
                        viewModel.goToNextPage()
                    },
                    onPageSelected: { page in
                        viewModel.loadPage(page)
                    },
                    onGoToLastPost: {
                        viewModel.goToLastPost()
                    },
                    onBookmarkTapped: {
                        viewModel.toggleBookmark()
                    },
                    onCopyLinkTapped: {
                        viewModel.copyLink()
                    },
                    onVoteTapped: {
                        // TODO: Implement vote functionality
                    },
                    onYourPostsTapped: {
                        // TODO: Implement your posts functionality  
                    }
                )
                .background(Color(theme[uicolor: "tabBarBackgroundColor"] ?? UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(theme[uicolor: "bottomBarTopBorderColor"] ?? UIColor.separator))
                        .frame(height: 0.5),
                    alignment: .top
                )
                .transition(.opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: scrollState.isBottomBarVisible)
                .padding(.bottom, postsImmersiveMode ? 0 : 0)
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if isLoadingSpinnerVisible {
                ZStack {
                    // Semi-transparent overlay to dim content - use black for YOSPOS, theme color for others
                    Color(theme[string: "postsLoadingViewType"] == "YOSPOS" ? .black : (theme[uicolor: "postsLoadingViewTintColor"] ?? .systemBackground))
                        .opacity(1)
                        .ignoresSafeArea()
                    
                    // Theme-specific loading animation
                    SwiftUILoadingViewFactory.loadingView(for: theme)
                    
                }
                .allowsHitTesting(false)
                .zIndex(1000) // High z-index to appear above everything
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleViewAppear() {
        // Set jumpToPostID from pending state after view is properly installed
        if let jumpToPostID = pendingJumpToPostID {
            print("🎯 SwiftUIPostsPageView: Setting jumpToPostID in view model after onAppear: \(jumpToPostID)")
            viewModel.jumpToPostID = jumpToPostID
            pendingJumpToPostID = nil
        }
        
        if viewModel.posts.isEmpty && !viewModel.isLoading {
            if let specificPage = specificPageToLoad {
                // Load the specific page that was requested
                print("🔵 SwiftUIPostsPageView: Loading specific page: \(specificPage)")
                viewModel.loadPage(specificPage, updatingCache: true, updatingLastReadPost: false)
                specificPageToLoad = nil // Clear it so we don't load again
            } else {
                // Use default page detection logic
                viewModel.loadInitialPage()
            }
        }
        setupHandoff()
    }
    
    private func handleViewDisappear() {
        scrollState.reset()
        arrowPullProgress = 0.0
        invalidateHandoff()
        
        // Save current scroll position for potential restoration
        saveScrollPosition()
    }
    
    private func replyWorkspaceSheet(_ identifiableWorkspace: IdentifiableReplyWorkspace) -> some View {
        ReplyWorkspaceView(
            workspace: identifiableWorkspace.workspace,
            onDismiss: { result in
                replyWorkspace = nil
                
                // Handle different completion results
                switch result {
                case .posted:
                    // Refresh the posts to show the new reply
                    viewModel.refresh()
                case .saveDraft:
                    // Draft was saved, no action needed
                    break
                case .forgetAboutIt:
                    // User cancelled, no action needed
                    break
                }
            }
        )
        .environment(\.theme, theme)
    }
    
    private func handleScrollToFraction(_ fraction: CGFloat?) {
        if let fraction = fraction {
            // Find the render view container and scroll to fractional position
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let container = findRenderViewContainer(in: window) {
                let fractionalPoint = CGPoint(x: 0, y: fraction)
                container.renderView.scrollToFractionalOffset(fractionalPoint)
            }
            viewModel.scrollToFraction = nil
        }
    }
    
    private func handlePostsChanged(_ posts: [Post]) {
        print("📋 Posts changed: count=\(posts.count), jumpToPostID=\(viewModel.jumpToPostID ?? "nil")")
        
        // Apply pending scroll fraction when posts are loaded
        if !posts.isEmpty, let scrollFraction = pendingScrollFraction {
            // Delay slightly to ensure the content is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.scrollToFraction = scrollFraction
                pendingScrollFraction = nil
            }
        }
        
        // Jump to specific post if we have a jumpToPostID and posts are loaded
        if !posts.isEmpty, let jumpToPostID = viewModel.jumpToPostID {
            print("📍 Posts loaded, jumping to post: \(jumpToPostID)")
            // Wait longer for HTML rendering to complete and add retry logic
            attemptPostJump(postID: jumpToPostID, attempt: 1, maxAttempts: 3)
        } else if !posts.isEmpty {
            print("📋 Posts loaded but no jumpToPostID to process")
        }
    }
    
    // MARK: - Loading View
    var loadingView: some View {
        SwiftUILoadingViewFactory.loadingView(for: theme)
    }
    
    // MARK: - Frog Animation Properties
    var frogOpacity: CGFloat {
        // Simple binary visibility for now - can be enhanced later
        return scrollState.isNearBottom ? 1.0 : 0.0
    }
    
    var frogScale: CGFloat {
        return scrollState.isNearBottom ? 1.0 : 0.8
    }
    
    // MARK: - Helper Methods
    private func findRenderViewContainer(in view: UIView) -> RenderViewContainer? {
        if let container = view as? RenderViewContainer {
            return container
        }
        
        for subview in view.subviews {
            if let found = findRenderViewContainer(in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Post Navigation
    private func attemptPostJump(postID: String, attempt: Int, maxAttempts: Int) {
        print("🎯 Attempting post jump to \(postID) (attempt \(attempt)/\(maxAttempts))")
        
        // Progressive delay: longer waits for later attempts to ensure HTML is fully rendered
        let delay = TimeInterval(attempt) * 0.5 // 0.5s, 1.0s, 1.5s
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            
            // Verify we still have the same jumpToPostID (user hasn't navigated away)
            guard viewModel.jumpToPostID == postID else {
                print("🔍 Post jump cancelled - jumpToPostID changed")
                return
            }
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let container = findRenderViewContainer(in: window)
                print("🔍 Posts jump attempt \(attempt): Found render view container: \(container != nil)")
                
                if let container = container {
                    // Check if the container is ready (has content and webview is loaded)
                    guard container.hasContent else {
                        print("⏳ Container not ready yet, will retry...")
                        if attempt < maxAttempts {
                            attemptPostJump(postID: postID, attempt: attempt + 1, maxAttempts: maxAttempts)
                        } else {
                            print("❌ Max attempts reached, post jump failed")
                        }
                        return
                    }
                    
                    print("🎯 Posts jump attempt \(attempt): Calling jumpToPost on ready container")
                    container.jumpToPost(identifiedBy: postID)
                    
                    // Wait a brief moment to see if the jump succeeded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Clear jumpToPostID after attempting the jump
                        // Note: We clear it even if we can't verify success to prevent infinite retries
                        viewModel.jumpToPostID = nil
                        print("✅ Post jump completed, jumpToPostID cleared")
                    }
                } else {
                    print("❌ Posts jump attempt \(attempt): No render view container found")
                    if attempt < maxAttempts {
                        attemptPostJump(postID: postID, attempt: attempt + 1, maxAttempts: maxAttempts)
                    } else {
                        print("❌ Max attempts reached, clearing jumpToPostID")
                        viewModel.jumpToPostID = nil
                    }
                }
            } else {
                print("❌ Posts jump attempt \(attempt): No window scene or window found")
                if attempt < maxAttempts {
                    attemptPostJump(postID: postID, attempt: attempt + 1, maxAttempts: maxAttempts)
                } else {
                    print("❌ Max attempts reached, clearing jumpToPostID")
                    viewModel.jumpToPostID = nil
                }
            }
        }
    }
    
    
    // MARK: - Action Handlers
    func handlePostAction(_ post: Post, rect: CGRect) {
        // No longer needed - context menu is handled in SwiftUIRenderView
    }
    
    func handleUserAction(_ post: Post, rect: CGRect) {
        // User action handling - could be implemented later if needed
    }
    
    func handleGoToParentForum() {
        guard thread.forum != nil else { return }
        
        // For now, just dismiss until we have proper coordinator access
        dismiss()
    }
    
    
    // MARK: - Scroll Management
    // Note: Scroll management is now handled by the WebKit view itself
    
    // MARK: - Handoff
    func setupHandoff() {
        guard handoffEnabled else { return }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
        activity.title = thread.title
        
        if let currentPage = viewModel.currentPage {
            let route: AwfulRoute
            if let author = author {
                route = .threadPageSingleUser(threadID: thread.threadID, userID: author.userID, page: currentPage, .noseen)
            } else {
                route = .threadPage(threadID: thread.threadID, page: currentPage, .noseen)
            }
            activity.route = route
        }
        
        // Note: In SwiftUI, we don't have direct access to the view controller's userActivity
        // This would need to be handled by the hosting controller or coordinator
    }
    
    func invalidateHandoff() {
        // Note: In SwiftUI, handoff invalidation would need to be handled by the hosting controller
    }
    
    // MARK: - Scroll Position Restoration
    private func saveScrollPosition() {
        // Update the navigation coordinator with current scroll position
        // This will allow restoration when navigating back to this thread
        if let coordinator = coordinator as? MainCoordinatorImpl {
            print("💾 saveScrollPosition: Saving for threadID: \(thread.threadID), page: \(viewModel.currentPage ?? .specific(1)), scrollFraction: \(currentScrollFraction)")
            coordinator.updateScrollPosition(
                for: thread.threadID,
                page: viewModel.currentPage ?? .specific(1),
                author: author,
                scrollFraction: currentScrollFraction
            )
        }
    }
    
    
}


// MARK: - SwiftUI Frog Animation
private struct SwiftUIFrogAnimation: View {
    let theme: Theme
    let pullProgress: CGFloat
    let isVisible: Bool
    let onRefreshTriggered: () -> Void
    
    @State var hasTriggeredRefresh = false
    @FoilDefaultStorage(Settings.enableHaptics) var enableHaptics
    
    var body: some View {
        Group {
            if isVisible {
                FrogLottieView(
                    theme: theme,
                    pullProgress: pullProgress,
                    onRefreshTriggered: {
                        if !hasTriggeredRefresh && pullProgress >= 1.0 {
                            hasTriggeredRefresh = true
                            if enableHaptics {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            onRefreshTriggered()
                            
                            // Reset after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                hasTriggeredRefresh = false
                            }
                        }
                    }
                )
                .frame(width: 30, height: 30) // Smaller size to match constraints
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isVisible)
            }
        }
        .background(Color.clear)
    }
}

private struct FrogLottieView: UIViewRepresentable {
    let theme: Theme
    let pullProgress: CGFloat
    let onRefreshTriggered: () -> Void
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(
            animation: LottieAnimation.named("frogrefresh60"),
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Force smaller size constraints
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        animationView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // Set initial static state
        animationView.currentFrame = 0
        animationView.pause()
        
        // Configure colors based on theme
        let mainColor = ColorValueProvider(theme["getOutFrogColor"]!.lottieColorValue)
        let clearColor = ColorValueProvider(UIColor.clear.lottieColorValue)
        
        let mainOutline = AnimationKeypath(keys: ["**", "Stroke 1", "**", "Color"])
        let nostrils = AnimationKeypath(keys: ["**", "Group 1", "**", "Color"])
        let leftEye = AnimationKeypath(keys: ["**", "EyeA", "**", "Color"])
        let rightEye = AnimationKeypath(keys: ["**", "EyeB", "**", "Color"])
        let pupilA = AnimationKeypath(keys: ["**", "PupilA", "**", "Color"])
        let pupilB = AnimationKeypath(keys: ["**", "PupilB", "**", "Color"])
        
        if theme["mode"] == "light" {
            // outer eye stroke opaque in light mode
            animationView.setValueProvider(FloatValueProvider(100), keypath: AnimationKeypath(keys: ["**", "Outline", "**", "Opacity"]))
            animationView.setValueProvider(mainColor, keypath: pupilA)
            animationView.setValueProvider(mainColor, keypath: pupilB)
            
            // make eye whites invisible in light mode
            animationView.setValueProvider(clearColor, keypath: leftEye)
            animationView.setValueProvider(clearColor, keypath: rightEye)
        } else {
            // outer eye stroke invisible in dark mode
            animationView.setValueProvider(FloatValueProvider(0), keypath: AnimationKeypath(keys: ["**", "Outline", "**", "Opacity"]))
            
            // make eye whites opaque in dark mode theme
            animationView.setValueProvider(mainColor, keypath: leftEye)
            animationView.setValueProvider(mainColor, keypath: rightEye)
        }
        
        animationView.setValueProvider(mainColor, keypath: nostrils)
        animationView.setValueProvider(mainColor, keypath: mainOutline)
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // Update animation based on pull progress
        if pullProgress >= 1.0 {
            // Full pull - trigger animation and refresh
            if uiView.currentFrame < 25 {
                uiView.play(fromFrame: uiView.currentFrame, toFrame: 25, loopMode: .playOnce)
                onRefreshTriggered()
            }
        } else if pullProgress > 0.1 {
            // Progressive animation based on pull distance: frame 0 to 25
            let targetFrame = AnimationFrameTime(pullProgress * 25)
            uiView.currentFrame = targetFrame
        } else {
            // Reset to initial state
            uiView.pause()
            uiView.currentFrame = 0
        }
    }
}




// MARK: - ReplyWorkspaceView
struct ReplyWorkspaceView: UIViewControllerRepresentable {
    let workspace: ReplyWorkspace
    let onDismiss: (ReplyWorkspace.CompletionResult) -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = workspace.viewController
        
        // Set up the completion handler
        workspace.completion = { result in
            onDismiss(result)
        }
        
        // Apply theme to the navigation controller and its content
        applyTheme(to: viewController)
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update theme if needed
        applyTheme(to: uiViewController)
    }
    
    private func applyTheme(to viewController: UIViewController) {
        // Apply theme to navigation controller
        if let navController = viewController as? UINavigationController {
            navController.view.backgroundColor = theme[uicolor: "backgroundColor"]
            navController.navigationBar.barTintColor = theme[uicolor: "navigationBarTintColor"]
            navController.navigationBar.tintColor = theme[uicolor: "navigationBarTextColor"]
            navController.navigationBar.titleTextAttributes = [
                .foregroundColor: theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
            ]
            
            // Apply theme to the root view controller (CompositionViewController)
            if let compositionVC = navController.topViewController as? ViewController {
                compositionVC.themeDidChange()
            }
        }
        
        // Apply theme if it's a themed view controller
        if let themedViewController = viewController as? ViewController {
            themedViewController.themeDidChange()
        }
    }
}

// MARK: - Preview
#Preview {
    Text("SwiftUIPostsPageView Preview")
        .environment(\.theme, Theme.defaultTheme())
}
