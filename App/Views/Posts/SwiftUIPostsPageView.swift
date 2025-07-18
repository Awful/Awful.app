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
    @StateObject private var viewState = PostsPageViewState()
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage? = nil, coordinator: AnyObject? = nil, scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
        
        // Initialize state using the new PostsPageViewState
        let initialState = PostsPageViewState()
        initialState.pendingScrollFraction = scrollFraction
        initialState.specificPageToLoad = page
        initialState.pendingJumpToPostID = jumpToPostID
        self._viewState = StateObject(wrappedValue: initialState)
    }
    
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage = .specific(1), coordinator: AnyObject? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
    }
    
    // MARK: - Handler Functions
    private func handlePullChanged(_ pullData: PullData) {
        // Handle niggly pull (top)
        if pullData.topFraction > 0 {
            viewState.nigglyPullProgress = pullData.topFraction
            if pullData.topFraction >= 1.0 && !viewState.wasNigglyTriggered {
                viewState.wasNigglyTriggered = true
            }
        }
        
        // Handle bottom pulls
        if pullData.bottomFraction > 0 {
            // Handle arrow pull for next page (if setting is enabled and not last page)
            if pullForNext && !viewModel.isLastPage {
                viewState.arrowPullProgress = pullData.bottomFraction
                // Mark as triggered when threshold is reached, but don't navigate yet
                if pullData.bottomFraction >= 1.5 && !viewState.wasArrowTriggered {
                    viewState.wasArrowTriggered = true
                    print("🏹 Arrow pull triggered at threshold, waiting for release")
                }
            } else if !pullForNext {
                // If setting is disabled, reset arrow pull state
                viewState.arrowPullProgress = 0.0
                viewState.wasArrowTriggered = false
            }
            // Handle frog pull on last page
            else if viewModel.isLastPage {
                scrollState.handlePullChanged(fraction: pullData.bottomFraction, isLastPage: true)
                
                // Update frog refresh state based on pull progress (but not when refreshing)
                if !viewState.isFrogRefreshing {
                    let fraction = pullData.bottomFraction
                    if fraction > 0.1 { // Only show animation after meaningful pull
                        viewState.frogRefreshState = .pulling(fraction: fraction)
                        // Only trigger if fraction is significantly above 1.0 to prevent accidental triggers
                        if fraction >= 1.2 && !viewState.wasFrogTriggered && !viewState.isFrogRefreshing {
                            viewState.wasFrogTriggered = true
                            viewState.isFrogRefreshing = true
                            viewState.frogRefreshState = .triggered
                            print("🐸 Frog triggered! fraction: \(fraction)")
                            
                            // Transition to refreshing state and start refresh
                            DispatchQueue.main.async {
                                self.viewState.frogRefreshState = .refreshing
                                print("🐸 Set frogRefreshState to .refreshing from immediate trigger")
                            }
                            
                            viewModel.refresh()
                            print("🐸 Called viewModel.refresh() from immediate trigger")
                        }
                    } else {
                        // Only set to ready if not already ready
                        if viewState.frogRefreshState != .ready {
                            viewState.frogRefreshState = .ready
                        }
                    }
                }
            }
        } else {
            // Reset states when not pulling (but not when refreshing)
            if case .pulling(_) = viewState.frogRefreshState, !viewState.isFrogRefreshing {
                // Only set to ready if not already ready
                if viewState.frogRefreshState != .ready {
                    viewState.frogRefreshState = .ready
                }
            }
        }
    }
    
    private func handleRefreshTriggered() {
        if viewState.wasNigglyTriggered {
            viewState.isNigglyRefreshing = true
            viewModel.refresh()
            viewState.wasNigglyTriggered = false
        }
        
        if viewState.wasFrogTriggered {
            handleFrogRefreshTriggered()
            viewState.wasFrogTriggered = false
        }
    }
    
    private func handleArrowPullTriggered() {
        print("🏹 handleArrowPullTriggered called - navigating to next page")
        
        // Reset states and navigate to next page
        viewState.arrowPullProgress = 0.0
        viewState.pendingScrollFraction = nil
        viewModel.goToNextPage()
    }
    
    private func handleFrogRefreshTriggered() {
        print("🐸 handleFrogRefreshTriggered called - isFrogRefreshing: \(viewState.isFrogRefreshing)")
        
        // Don't start another refresh if one is already in progress
        guard !viewState.isFrogRefreshing else {
            print("🐸 Ignoring refresh trigger - already refreshing")
            return
        }
        
        viewState.isFrogRefreshing = true
        
        // Use DispatchQueue to ensure state update happens on main thread
        DispatchQueue.main.async {
            self.viewState.frogRefreshState = .refreshing
            print("🐸 Set frogRefreshState to .refreshing on main thread")
        }
        
        viewModel.refresh()
        print("🐸 Called viewModel.refresh()")
    }
    
    private func handleDragEnded(willDecelerate: Bool) {
        // Handle arrow pull trigger - only if setting is enabled and user actually released at the right time
        if pullForNext && viewState.wasArrowTriggered && !willDecelerate {
            print("🏹 Drag ended - navigating to next page")
            handleArrowPullTriggered()
            viewState.wasArrowTriggered = false
        } else if pullForNext && viewState.wasArrowTriggered && willDecelerate {
            // If still decelerating, don't trigger yet - wait for final position
            print("🏹 Drag ended but still decelerating - waiting")
        }
        
        // Handle frog refresh trigger - only if user actually released at the right time
        if viewState.wasFrogTriggered && !willDecelerate {
            print("🐸 Drag ended - starting frog refresh")
            handleFrogRefreshTriggered()
            viewState.wasFrogTriggered = false
        } else if viewState.wasFrogTriggered && willDecelerate {
            // If still decelerating, don't trigger yet - wait for final position
            print("🐸 Drag ended but still decelerating - waiting")
        }
        
        // Reset pull states if not triggered and not decelerating
        if !viewState.wasNigglyTriggered && !willDecelerate {
            viewState.nigglyPullProgress = 0.0
        }
        if (!viewState.wasArrowTriggered || !pullForNext) && !willDecelerate {
            viewState.arrowPullProgress = 0.0
        }
    }
    
    private func handleDecelerationEnded() {
        // Handle any pending arrow pull triggers after deceleration
        if pullForNext && viewState.wasArrowTriggered {
            print("🏹 Deceleration ended - checking if arrow pull should trigger")
            // Only trigger if we're still close to the pull threshold
            if viewState.arrowPullProgress >= 1.2 {
                print("🏹 Triggering arrow pull after deceleration")
                handleArrowPullTriggered()
            }
            viewState.wasArrowTriggered = false
        }
        
        // Handle any pending frog refresh triggers after deceleration
        if viewState.wasFrogTriggered && !viewState.isFrogRefreshing {
            print("🐸 Deceleration ended - checking if frog refresh should trigger")
            // Only trigger if we're still close to the pull threshold
            if frogPullProgress >= 1.0 {
                print("🐸 Triggering frog refresh after deceleration")
                handleFrogRefreshTriggered()
            }
            viewState.wasFrogTriggered = false
        }
        
        // Reset remaining pull states
        if !viewState.wasNigglyTriggered {
            viewState.nigglyPullProgress = 0.0
        }
        if !viewState.wasArrowTriggered || !pullForNext {
            viewState.arrowPullProgress = 0.0
        }
    }
    
    // MARK: - Body
    var body: some View {
        mainContentView
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(postsImmersiveMode)
            .navigationTitle(thread.title ?? "Thread")
            .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
            .statusBarHidden(false)
            .allowsHitTesting(true)
            .interactiveDismissDisabled(false)
            .overlay(alignment: .top) {
                if postsImmersiveMode && scrollState.isTopBarVisible {
                    VStack(spacing: 0) {
                        customNavigationBar
                        
                        if scrollState.isSubToolbarVisible {
                            topSubToolbar
                        }
                    }
                    .background(Color(theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(Color(theme[uicolor: "topBarBottomBorderColor"] ?? UIColor.separator))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                    .ignoresSafeArea(.container, edges: .top)
                    .animation(.easeInOut(duration: 0.25), value: scrollState.isTopBarVisible)
                }
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
                            viewState.replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
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
                // Ensure scroll state is properly initialized for immersive mode
                scrollState.setIsImmersiveMode(postsImmersiveMode)
                
                // In immersive mode, ensure the top bar is visible on initial load
                if postsImmersiveMode {
                    // Force the top bar to be visible initially
                    scrollState.reset()
                    scrollState.setIsImmersiveMode(postsImmersiveMode)
                }
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                viewState.isLoadingSpinnerVisible = isLoading
                
                // Reset niggly refresh state when loading completes
                if !isLoading && viewState.isNigglyRefreshing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewState.isNigglyRefreshing = false
                    }
                }
                
                // Reset frog refresh state when loading completes
                if !isLoading && viewState.isFrogRefreshing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewState.isFrogRefreshing = false
                        // Only set to ready if not already ready
                        if viewState.frogRefreshState != .ready {
                            viewState.frogRefreshState = .ready
                        }
                    }
                }
            }
            .onDisappear {
                handleViewDisappear()
            }
            .sheet(item: $viewState.replyWorkspace) { identifiableWorkspace in
                replyWorkspaceSheet(identifiableWorkspace)
            }
            .sheet(isPresented: $viewState.showingSettings) {
                PostsPageSettingsView()
                    .environment(\.theme, theme)
            }
            .sheet(isPresented: $viewState.showingImageViewer) {
                if let imageURL = viewState.presentedImageURL {
                    SwiftUIImageViewer(imageURL: imageURL)
                        .environment(\.theme, theme)
                }
            }
            .onChange(of: viewState.showingImageViewer) { isShowing in
                print("🖼️ showingImageViewer changed to: \(isShowing)")
                if !isShowing {
                    // Delay the reset slightly to ensure sheet dismissal completes
                    // and to minimize interference with WebView coordinate calculations
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewState.presentedImageURL = nil
                        print("🖼️ Image viewer dismissed, reset presentedImageURL after delay")
                    }
                }
            }
            .onChange(of: viewState.presentedImageURL) { newURL in
                print("🖼️ presentedImageURL changed to: \(String(describing: newURL))")
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
                .ignoresSafeArea(.all) // Always extend to all areas for consistent overscroll background
                .zIndex(-1) // Ensure background is behind other content
            
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
        SwiftUIRenderView(
            viewModel: viewModel,
            theme: theme,
            onPostAction: handlePostAction,
            onUserAction: handleUserAction,
            onScrollChanged: { isScrollingUp in
                scrollState.setIsLastPage(viewModel.isLastPage)
                scrollState.setIsImmersiveMode(postsImmersiveMode)
                scrollState.handleScrollChange(isScrollingUp: isScrollingUp)
            },
            onPullChanged: { pullData in
                handlePullChanged(pullData)
            },
            onRefreshTriggered: {
                handleRefreshTriggered()
            },
            onScrollPositionChanged: { offset, contentHeight, viewHeight in
                scrollState.handleScrollPositionChanged(offset: offset, contentHeight: contentHeight, viewHeight: viewHeight)
            },
            onDragEnded: { willDecelerate in
                handleDragEnded(willDecelerate: willDecelerate)
            },
            onDecelerationEnded: {
                handleDecelerationEnded()
            },
            replyWorkspace: $viewState.replyWorkspace,
            presentedImageURL: $viewState.presentedImageURL,
            showingImageViewer: $viewState.showingImageViewer,
            topInset: scrollState.topInset,
            bottomInset: calculateBottomInset(),
            isImmersiveMode: postsImmersiveMode,
            // Removed frog content parameters
        )
        .id("render-view-\(viewModel.thread.threadID)-\(viewModel.currentPage.map { "\($0)" } ?? "unknown")")
        .background(Color(theme[uicolor: "postsViewBackgroundColor"] ?? UIColor.systemBackground))
        .ignoresSafeArea(postsImmersiveMode ? .all : .container)
        .overlay(alignment: .center) {
            NigglyPullOverlay(
                theme: theme,
                pullProgress: viewState.nigglyPullProgress,
                isRefreshing: viewState.isNigglyRefreshing,
                isVisible: frogAndGhostEnabled && (viewState.nigglyPullProgress > 0.1 || viewState.isNigglyRefreshing),
                isImmersiveMode: postsImmersiveMode
            )
        }
        .overlay(alignment: .bottom) {
            ArrowPullOverlay(
                theme: theme,
                pullProgress: viewState.arrowPullProgress,
                isVisible: pullForNext && frogAndGhostEnabled && !viewModel.isLastPage && viewState.arrowPullProgress > 0.2,
                horizontalSizeClass: horizontalSizeClass,
                onNavigateToNextPage: {
                    // Navigation is now handled in drag end logic
                    // This callback is only for visual feedback
                }
            )
        }
        .overlay(alignment: .bottom) {
            // Frog refresh overlay for bottom pull on last page
            if frogAndGhostEnabled && viewModel.isLastPage {
                VStack {
                    Spacer()
                    FrogRefreshAnimation(
                        theme: theme,
                        refreshState: $viewState.frogRefreshState
                    )
                    .frame(width: 60, height: 60)
                    .offset(y: postsImmersiveMode ? -40 : -100) // Position above bottom toolbar
                    .opacity(scrollState.isNearBottom ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: scrollState.isNearBottom)
                }
            }
        }
    }
    
    // MARK: - Custom Navigation Bar
    private var customNavigationBar: some View {
        VStack(spacing: 0) {
            // Safe area spacer
            Color.clear
                .frame(height: 44) // Standard safe area height
            
            // Navigation bar content positioned below safe area
            HStack(alignment: .center) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                }
                .padding(.leading, 16)
                
                Spacer()
                
                Text(thread.title ?? "Thread")
                    .font(.headline)
                    .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                Button(action: {
                    viewModel.replyToPost { workspace in
                        viewState.replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                    }
                }) {
                    Image("compose")
                        .renderingMode(.template)
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                }
                .padding(.trailing, 16)
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)
            .background(Color(theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground))
        }
        .background(Color(theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground))
    }
    
    // MARK: - Top Subtoolbar
    private var topSubToolbar: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Previous Posts") {
                    viewModel.goToPreviousPage()
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
    }
    
    // MARK: - Bottom Overlays
    private var bottomOverlays: some View {
        VStack(spacing: 0) {
            // Bottom toolbar overlay - show in normal mode or when visible in immersive mode
            if !postsImmersiveMode {
                // Always show in normal mode
                PostsToolbarContainer(
                    thread: thread,
                    author: author,
                    page: viewModel.currentPage,
                    numberOfPages: viewModel.numberOfPages,
                    isLoadingViewVisible: viewState.isLoadingSpinnerVisible,
                    onSettingsTapped: {
                        viewState.showingSettings = true
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
            } else if scrollState.isBottomBarVisible {
                // Only show in immersive mode when scroll state indicates it should be visible
                PostsToolbarContainer(
                    thread: thread,
                    author: author,
                    page: viewModel.currentPage,
                    numberOfPages: viewModel.numberOfPages,
                    isLoadingViewVisible: viewState.isLoadingSpinnerVisible,
                    onSettingsTapped: {
                        viewState.showingSettings = true
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
                .offset(y: scrollState.isBottomBarVisible ? 0 : 120)
                .animation(.easeInOut(duration: 0.25), value: scrollState.isBottomBarVisible)
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            // Only show regular loading overlay if not using frog refresh on last page
            if viewState.isLoadingSpinnerVisible && !(viewModel.isLastPage && viewState.isFrogRefreshing && frogAndGhostEnabled) {
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
        print("🔵 SwiftUIPostsPageView: handleViewAppear - posts.count: \(viewModel.posts.count), isLoading: \(viewModel.isLoading)")
        
        // Set jumpToPostID from pending state after view is properly installed
        if let jumpToPostID = viewState.pendingJumpToPostID {
            print("🎯 SwiftUIPostsPageView: Setting jumpToPostID in view model after onAppear: \(jumpToPostID)")
            viewModel.jumpToPostID = jumpToPostID
            viewState.pendingJumpToPostID = nil
        }
        
        // Force reload if we have posts but webview might not be properly restored
        if !viewModel.posts.isEmpty && !viewModel.isLoading {
            print("🔵 SwiftUIPostsPageView: Posts available, checking if webview needs refresh")
            // Check if webview container has content - if not, force a re-render
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let container = findRenderViewContainer(in: window) {
                if !container.hasContent {
                    print("🔵 SwiftUIPostsPageView: Webview container has no content, forcing re-render")
                    // Force re-render with existing posts
                    viewModel.refresh()
                }
            }
        } else if viewModel.posts.isEmpty && !viewModel.isLoading {
            if let specificPage = viewState.specificPageToLoad {
                // Load the specific page that was requested
                print("🔵 SwiftUIPostsPageView: Loading specific page: \(specificPage)")
                // Always update read position - server should track page views
                viewModel.loadPage(specificPage, updatingCache: true, updatingLastReadPost: true)
                viewState.specificPageToLoad = nil // Clear it so we don't load again
            } else {
                // Use default page detection logic
                print("🔵 SwiftUIPostsPageView: Loading initial page for thread: \(viewModel.thread.title ?? "Unknown")")
                viewModel.loadInitialPage()
            }
        } else {
            print("🔵 SwiftUIPostsPageView: Skipping load - posts: \(viewModel.posts.count), isLoading: \(viewModel.isLoading)")
        }
        setupHandoff()
    }
    
    private func handleViewDisappear() {
        scrollState.reset()
        viewState.resetPullStates()
        invalidateHandoff()
        
        // Save current scroll position for potential restoration
        saveScrollPosition()
    }
    
    private func replyWorkspaceSheet(_ identifiableWorkspace: IdentifiableReplyWorkspace) -> some View {
        ReplyWorkspaceView(
            workspace: identifiableWorkspace.workspace,
            onDismiss: { result in
                viewState.replyWorkspace = nil
                
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
        if !posts.isEmpty, let scrollFraction = viewState.pendingScrollFraction {
            // Delay slightly to ensure the content is rendered - longer delay on iPad
            let delay = horizontalSizeClass == .regular ? 0.3 : 0.1
            print("📋 Applying scroll fraction \(scrollFraction) after \(delay)s delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                viewModel.scrollToFraction = scrollFraction
                viewState.pendingScrollFraction = nil
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
    
    var frogPullProgress: CGFloat {
        switch viewState.frogRefreshState {
        case .ready:
            return 0.0
        case .pulling(let fraction):
            return fraction
        case .triggered:
            return 1.2
        case .refreshing:
            return 1.2
        case .disabled:
            return 0.0
        }
    }
    
    // MARK: - Content Inset Calculation
    private func calculateBottomInset() -> CGFloat {
        if postsImmersiveMode {
            // In immersive mode, toolbars are overlays, need space for reading + frog access
            let baseSpace: CGFloat = 80 // Base space for reading
            let frogSpace: CGFloat = (frogAndGhostEnabled && viewModel.isLastPage) ? 120 : 0 // More space for frog interaction
            return baseSpace + frogSpace
        } else {
            // In normal mode, provide space for toolbar + reading + frog interaction
            let toolbarSpace: CGFloat = 60 // Space for bottom toolbar
            let readingSpace: CGFloat = 60 // Additional space for comfortable reading
            let frogSpace: CGFloat = (frogAndGhostEnabled && viewModel.isLastPage) ? 120 : 0 // Extra space for frog pull area
            return toolbarSpace + readingSpace + frogSpace
        }
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
            print("💾 saveScrollPosition: Saving for threadID: \(thread.threadID), page: \(viewModel.currentPage ?? .specific(1)), scrollFraction: \(viewState.currentScrollFraction)")
            coordinator.updateScrollPosition(
                for: thread.threadID,
                page: viewModel.currentPage ?? .specific(1),
                author: author,
                scrollFraction: viewState.currentScrollFraction
            )
        }
    }
    
    
}


// MARK: - Pull Control Overlays
/// Niggly pull control overlay that appears when pulling from top
private struct NigglyPullOverlay: View {
    let theme: Theme
    let pullProgress: CGFloat
    let isRefreshing: Bool
    let isVisible: Bool
    let isImmersiveMode: Bool
    
    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                    .frame(height: isImmersiveMode ? 85 : 125)
                
                SwiftUINigglyPullControl(
                    theme: theme,
                    pullProgress: isRefreshing ? 1.0 : pullProgress,
                    isVisible: true,
                    isRefreshing: isRefreshing,
                    onRefreshTriggered: {
                        // Handled by parent scroll coordinator
                    }
                )
                
                Spacer()
            }
            .offset(y: -162 + (pullProgress * 125))
            .allowsHitTesting(false)
        }
    }
}

/// Arrow pull control overlay for navigating to next page
private struct ArrowPullOverlay: View {
    let theme: Theme
    let pullProgress: CGFloat
    let isVisible: Bool
    let horizontalSizeClass: UserInterfaceSizeClass?
    let onNavigateToNextPage: () -> Void
    
    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                SwiftUIArrowPullControl(
                    theme: theme,
                    pullProgress: pullProgress,
                    isVisible: true,
                    onRefreshTriggered: {
                        DispatchQueue.main.async {
                            onNavigateToNextPage()
                        }
                    }
                )
                .offset(y: horizontalSizeClass == .regular ? 10 : 40)
            }
        }
    }
}












// MARK: - Supporting Types
// No longer needed - using isPresented binding instead of item binding

// MARK: - SwiftUI Image Viewer
// SwiftUIImageViewer is now defined in ImageViewController.swift


// MARK: - Preview
#Preview {
    Text("SwiftUIPostsPageView Preview")
        .environment(\.theme, Theme.defaultTheme())
}
