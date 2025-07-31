//  SwiftUIPostsPageView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import SwiftUI
import UIKit
import WebKit
// import Lottie  // Temporarily removed for performance testing
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIPostsPageView")



struct SwiftUIPostsPageView: View {
    let thread: AwfulThread
    let author: User?
    let coordinator: AnyObject?
    let isPresentedModally: Bool
    
    @StateObject private var viewModel: PostsPageViewModel
    @SwiftUI.Environment(\.theme) private var globalTheme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Forum-Specific Theme
    private var theme: Theme {
        guard let forum = thread.forum, !forum.forumID.isEmpty else {
            return Theme.defaultTheme()
        }
        let forumTheme = Theme.currentTheme(for: ForumID(forum.forumID))
        print("🎨 Forum \(forum.forumID): Using theme '\(forumTheme[string: "description"] ?? "unknown")' mode '\(forumTheme[string: "mode"] ?? "unknown")'")
        return forumTheme
    }
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    @FoilDefaultStorage(Settings.postsImmersiveMode) private var postsImmersiveMode
    @FoilDefaultStorage(Settings.enableLiquidGlass) private var enableLiquidGlass
    
    // MARK: - State Management
    // @StateObject private var scrollState = ScrollStateManager()  // Temporarily removed for performance testing
    @StateObject private var viewState = PostsPageViewState()
    @State private var showingPagePicker = false
    @State private var currentUserActivity: NSUserActivity?
    @StateObject private var scrollCoordinator = RenderViewScrollCoordinator()
    
    // MARK: - Immersive Mode State  
    @State private var isToolbarVisible = true
    @State private var isNavigationBarVisible = true
    
    // MARK: - Cached Performance State
    @State private var useLiquidGlass: Bool
    
    
    // MARK: - Simplified Scroll Management (mirroring UIKit approach)
    @State private var hasAttemptedInitialScroll = false
    @State private var scrollTarget: ScrollTarget?
    @State private var handleViewAppearCallCount = 0
    @State private var isScrollingComplete = false
    
    enum ScrollTarget {
        case specificPost(String)      // Priority 1: Highest (jumpToPostID)
        case fraction(CGFloat)         // Priority 2: State restoration
        case lastPost                  // Priority 3: Jump to end  
        case firstUnread              // Priority 4: Default for .nextUnread
    }
    
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage? = nil, coordinator: AnyObject? = nil, scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil, isPresentedModally: Bool = false) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self.isPresentedModally = isPresentedModally
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
        
        // Initialize liquid glass state immediately based on iOS version
        if #available(iOS 26.0, *) {
            // We'll update this properly in onAppear, start with true for iOS 26+
            self._useLiquidGlass = State(initialValue: true)
        } else {
            self._useLiquidGlass = State(initialValue: false)
        }
        
        // Initialize state using the new PostsPageViewState
        let initialState = PostsPageViewState()
        initialState.pendingScrollFraction = scrollFraction
        initialState.specificPageToLoad = page
        initialState.pendingJumpToPostID = jumpToPostID
        self._viewState = StateObject(wrappedValue: initialState)
    }
    
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage = .specific(1), coordinator: AnyObject? = nil, isPresentedModally: Bool = false) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self.isPresentedModally = isPresentedModally
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
        
        // Initialize liquid glass state immediately based on iOS version
        if #available(iOS 26.0, *) {
            // We'll update this properly in onAppear, start with true for iOS 26+
            self._useLiquidGlass = State(initialValue: true)
        } else {
            self._useLiquidGlass = State(initialValue: false)
        }
        
        let initialState = PostsPageViewState()
        initialState.specificPageToLoad = page
        self._viewState = StateObject(wrappedValue: initialState)
    }
    
    // MARK: - Handler Functions (temporarily removed for performance testing)
    /*
    private func handlePullChanged(_ pullData: PullData) {
        // All pull handling code temporarily removed for performance testing
    }
    */
    
    /*
    private func handleRefreshTriggered() {
        // Temporarily removed for performance testing
    }
    */
    
    /*
    private func handleArrowPullTriggered() {
        // Temporarily removed for performance testing
    }
    */
    
    /*
    private func handleFrogRefreshTriggered() {
        // Temporarily removed for performance testing
    }
    */
    
    /*
    private func handleDragEnded(willDecelerate: Bool) {
        // Temporarily removed for performance testing
    }
    */
    
    /*
    private func handleDecelerationEnded() {
        // Temporarily removed for performance testing
    }
    */
    
    // MARK: - Body
    var body: some View {
        let colorScheme: ColorScheme = theme["mode"] == "dark" ? .dark : .light
        
        return mainContentView
            .backSwipeGesture(coordinator: coordinator as? (any MainCoordinator))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(navigationBarVisibility, for: .navigationBar)
            .preferredColorScheme(colorScheme)
            .statusBarHidden(false)
            .allowsHitTesting(true)
            .interactiveDismissDisabled(false)
            .overlay(alignment: .bottom) {
                bottomOverlays
            }
            .overlay(alignment: .center) {
                loadingOverlay
            }
            .simultaneousGesture(
                // Only add gesture when immersion mode is active
                postsImmersiveMode ? 
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
                : nil
            )
            .toolbar {
                // Custom multiline title
                ToolbarItem(placement: .principal) {
                    Text(thread.title ?? "Thread")
                        .postTitleFont(theme: theme)
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Done button for modal presentation or back button for navigation
                if isPresentedModally {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Use coordinator for navigation
                            if let coordinator = coordinator as? MainCoordinatorImpl {
                                coordinator.goBack()
                            } else {
                                // Fallback to dismiss if no coordinator
                                dismiss()
                            }
                        }) {
                            Image("back")
                                .renderingMode(.template)
                        }
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                    }
                }
                
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
                
                // Always add liquid glass toolbar content, but make it conditional internally
                liquidGlassToolbarContent
            }
            .toolbar(toolbarVisibility, for: .bottomBar)
            .onAppear {
                // theme set at init - no need to update
                updateLiquidGlassState()
                handleViewAppear()
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                // Keep spinner visible until both loading and scrolling are complete
                if !isLoading {
                    // Loading is complete, but keep spinner until scrolling is done
                    print("🔄 Loading complete, waiting for scrolling to finish...")
                    handleInitialScrolling(posts: viewModel.posts)
                } else {
                    // Reset scrolling state when new loading starts
                    isScrollingComplete = false
                    viewState.isLoadingSpinnerVisible = true
                }
                
                // Update spinner visibility based on both loading and scrolling state
                updateLoadingSpinnerVisibility()
                
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
                    
            }
            .sheet(isPresented: $viewState.showingImageViewer) {
                if let imageURL = viewState.presentedImageURL {
                    SwiftUIImageViewer(imageURL: imageURL)
                        
                }
            }
            .confirmationDialog("Rate this thread", isPresented: $viewState.showingVoteSheet) {
                ForEach(1...5, id: \.self) { rating in
                    Button("\(rating) Star\(rating > 1 ? "s" : "")") {
                        viewModel.vote(rating: rating)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("How would you rate this thread?")
            }
            .alert(viewState.alertTitle ?? "Error", isPresented: .constant(viewState.alertTitle != nil)) {
                Button("OK") {
                    viewState.alertTitle = nil
                    viewState.alertMessage = nil
                }
            } message: {
                if let alertMessage = viewState.alertMessage {
                    Text(alertMessage)
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
            .onChange(of: viewModel.jumpToPostID) { postID in
                handleJumpToPostIDChanged(postID)
            }
            .onChange(of: viewModel.currentPage) { page in
                // Update handoff when page changes
                if handoffEnabled && page != nil {
                    setupHandoff()
                }
                
                // Reset toolbar visibility on page change
                resetToolbarVisibility()
                
                // Reset scroll state for new page
                hasAttemptedInitialScroll = false
                isScrollingComplete = false
                updateLoadingSpinnerVisibility()
                print("🔄 Page changed to \(String(describing: page)) - reset scroll state")
            }
            .onChange(of: enableLiquidGlass) { _ in
                updateLiquidGlassState()
            }
            .onChange(of: postsImmersiveMode) { newValue in
                if newValue {
                    resetToolbarVisibility()
                    startImmersionModeIfNeeded()
                } else {
                    stopImmersionMode()
                }
            }
    }
    
    // MARK: - Drag-Based Immersion Mode
    @State private var dragState: DragState = .idle
    @State private var lastDragTranslation: CGFloat = 0
    @State private var lastTransitionTime: Date = Date.distantPast
    
    // MARK: - Gesture Detection Constants
    private let minimumDragThreshold: CGFloat = 15 // Larger threshold to not interfere with scrolling
    private let transitionCooldownInterval: TimeInterval = 0.6 // Prevent rapid toggling
    
    enum DragState {
        case idle
        case dragging
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        guard postsImmersiveMode else { return }
        
        let now = Date()
        
        // Check cooldown period to prevent rapid toggling
        let timeSinceLastTransition = now.timeIntervalSince(lastTransitionTime)
        guard timeSinceLastTransition > transitionCooldownInterval else { return }
        
        switch dragState {
        case .idle:
            dragState = .dragging
            lastDragTranslation = value.translation.height
            
        case .dragging:
            let currentTranslation = value.translation.height
            let deltaY = currentTranslation - lastDragTranslation
            
            // Only trigger on significant movement to not interfere with scrolling
            if abs(deltaY) > minimumDragThreshold {
                if deltaY < -minimumDragThreshold && isToolbarVisible {
                    // Dragging up significantly - hide toolbars
                    lastTransitionTime = now
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        isToolbarVisible = false
                        isNavigationBarVisible = false
                    }
                } else if deltaY > minimumDragThreshold && !isToolbarVisible {
                    // Dragging down significantly - show toolbars
                    lastTransitionTime = now
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                        isToolbarVisible = true
                        isNavigationBarVisible = true
                    }
                }
            }
            
            lastDragTranslation = currentTranslation
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        dragState = .idle
        lastDragTranslation = 0
    }
    
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            // Simple background safe area behavior: extend when immersive mode is enabled
            if postsImmersiveMode {
                // Full-screen background that extends into all safe areas for immersive mode
                Color(theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground)
                    .ignoresSafeArea(.all) // Extend to all areas for immersive mode
                    .zIndex(-1) // Ensure background is behind other content
            } else {
                // Constrained background for normal mode to respect navigation areas 
                Color(theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground)
                    .ignoresSafeArea(.container, edges: .horizontal) // Only extend horizontally
                    .zIndex(-1) // Ensure background is behind other content
            }
            
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
    @ViewBuilder
    private var mainRenderView: some View {
        let baseView = SwiftUIRenderViewNative(
            viewModel: viewModel,
            theme: theme,
            thread: thread,
            author: author,
            scrollCoordinator: scrollCoordinator,
            onPostAction: handlePostAction,
            onUserAction: handleUserAction,
            onContentRestored: {
                print("🔧 SwiftUIPostsPageView: Received WebView content restoration notification for ViewModel[\(viewModel.debugInstanceID)]")
                viewModel.markWebViewContentAsRestored()
            }
        )
        // .id() removed - was causing entire view recreation and performance issues
        .background(Color(theme[uicolor: "postsViewBackgroundColor"] ?? UIColor.systemBackground))
        
        // Simple safe area behavior: extend when immersive mode is enabled (setting)
        if postsImmersiveMode {
            baseView.ignoresSafeArea(.container)
        } else {
            baseView
        }
        // All pull overlays temporarily removed for performance testing
        /*
        .overlay(alignment: .center) {
            NigglyPullOverlay(...)
        }
        .overlay(alignment: .bottom) {
            ArrowPullOverlay(...)
        }
        .overlay(alignment: .bottom) {
            // Frog refresh overlay
        }
        */
    }
    
    // MARK: - Top Overlays
    private var topOverlays: some View {
        VStack(spacing: 0) {
            // Show custom navigation bar only in immersive mode when visible
            if postsImmersiveMode && isNavigationBarVisible {
                customNavigationBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Custom Navigation Bar
    private var customNavigationBar: some View {
        HStack(alignment: .center) {
            if isPresentedModally {
                Button("Done") {
                    dismiss()
                }
                .font(.body.weight(.medium))
                .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                .padding(.leading, 16)
            } else {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                }
                .padding(.leading, 16)
            }
            
            Spacer()
            
            Text(thread.title ?? "Thread")
                .postTitleFont(theme: theme)
                .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
                .lineLimit(UIDevice.current.userInterfaceIdiom == .pad ? 1 : 2)
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
        .padding(.top, 44) // Add top padding for safe area when used as overlay
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
                    viewModel.scrollToEnd()
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
        let showOverlay = shouldShowToolbar && !useLiquidGlass
        
        return Group {
            if showOverlay {
                standardToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear { 
                        print("🔧 TOOLBAR SHOWING: standardToolbar overlay appeared - Device: \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
                    }
            } else {
                // Add debug info when toolbar is hidden
                Color.clear
                    .onAppear {
                        print("🚫 TOOLBAR HIDDEN: showOverlay=false, shouldShowToolbar=\(shouldShowToolbar), useLiquidGlass=\(useLiquidGlass), postsImmersiveMode=\(postsImmersiveMode), isToolbarVisible=\(isToolbarVisible) - Device: \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
                    }
            }
        }
        .onAppear {
            print("🔧 bottomOverlays evaluated: shouldShowToolbar=\(shouldShowToolbar), useLiquidGlass=\(useLiquidGlass), showOverlay=\(showOverlay), postsImmersiveMode=\(postsImmersiveMode), enableLiquidGlass=\(enableLiquidGlass) - Device: \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
        }
    }
    
    // MARK: - Toolbar Decision Logic
    private var shouldShowToolbar: Bool {
        if postsImmersiveMode {
            // In immersive mode, use scroll-based visibility
            print("🔧 shouldShowToolbar: immersive mode ON, isToolbarVisible=\(isToolbarVisible) -> returning \(isToolbarVisible)")
            return isToolbarVisible
        } else {
            // In normal mode, always show toolbar
            print("🔧 shouldShowToolbar: immersive mode OFF, always showing -> returning true")
            return true
        }
    }
    
    private var toolbarVisibility: Visibility {
        if useLiquidGlass {
            // For liquid glass, use native toolbar and control visibility
            if postsImmersiveMode {
                return isToolbarVisible ? .visible : .hidden
            } else {
                return .visible
            }
        } else {
            // For non-liquid glass, always hide native toolbar and use overlay instead
            return .hidden
        }
    }
    
    
    private var navigationBarVisibility: Visibility {
        if postsImmersiveMode {
            // In immersive mode, control navigation bar visibility
            return isNavigationBarVisible ? .visible : .hidden
        } else {
            // In normal mode, always show navigation bar
            return .visible
        }
    }
    
    private func updateLiquidGlassState() {
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("🌟 Current iOS version: \(currentVersion.majorVersion).\(currentVersion.minorVersion).\(currentVersion.patchVersion)")
        print("🌟 Device: \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
        
        if #available(iOS 26.0, *) {
            useLiquidGlass = enableLiquidGlass
            print("🌟 Liquid Glass: Available on iOS 26+, enableLiquidGlass=\(enableLiquidGlass), useLiquidGlass=\(useLiquidGlass)")
        } else {
            useLiquidGlass = false
            print("🌟 Liquid Glass: Not available on iOS <26, enableLiquidGlass=\(enableLiquidGlass), useLiquidGlass=false")
        }
        print("🌟 Final state: useLiquidGlass=\(useLiquidGlass), postsImmersiveMode=\(postsImmersiveMode)")
        print("🌟 Should show native toolbar: \(useLiquidGlass), should show overlay: \(!useLiquidGlass)")
        print("🌟 Toolbar visibility will be: \(useLiquidGlass ? (postsImmersiveMode ? (isToolbarVisible ? "visible" : "hidden") : "visible") : "hidden")")
    }
    
    
    // MARK: - Toolbar Content (Native iOS Toolbar)
    @ToolbarContentBuilder
    private var liquidGlassToolbarContent: some ToolbarContent {
        // Show when liquid glass is enabled and toolbar should be visible
        // In immersive mode, we still use native toolbar but control visibility with .toolbar(.visible/.hidden)
        if #available(iOS 26.0, *), useLiquidGlass && shouldShowToolbar {
            let _ = print("🌟 Using liquid glass toolbar content")
            LiquidGlassBottomBar.toolbarContent(
                thread: thread,
                page: viewModel.currentPage,
                numberOfPages: viewModel.numberOfPages,
                showingPagePicker: $showingPagePicker,
                toolbarTextColor: Color(theme[uicolor: "toolbarTextColor"] ?? .systemBlue),
                roundedFonts: theme.roundedFonts,
                isBackEnabled: {
                    switch viewModel.currentPage {
                    case .specific(let pageNumber)?:
                        return pageNumber > 1
                    case .last?, .nextUnread?, nil:
                        return false
                    }
                }(),
                isForwardEnabled: {
                    switch viewModel.currentPage {
                    case .specific(let pageNumber)?:
                        return pageNumber < viewModel.numberOfPages
                    case .last?, .nextUnread?, nil:
                        return false
                    }
                }(),
                currentPageAccessibilityLabel: {
                    if case .specific(let pageNumber) = viewModel.currentPage, viewModel.numberOfPages > 0 {
                        return "Page \(pageNumber) of \(viewModel.numberOfPages)"
                    } else {
                        return ""
                    }
                }(),
                isImmersiveModeActive: postsImmersiveMode && !isToolbarVisible,
                onSettingsTapped: {
                    viewState.showingSettings = true
                },
                onBackTapped: {
                    withAnimation(.smooth(duration: 0.8)) {
                        viewModel.goToPreviousPage()
                    }
                },
                onForwardTapped: {
                    withAnimation(.smooth(duration: 0.8)) {
                        viewModel.goToNextPage()
                    }
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
                    viewState.showingVoteSheet = true
                },
                onYourPostsTapped: {
                    viewModel.showYourPosts(coordinator: coordinator as? (any MainCoordinator))
                }
            )
        }
    }
    
    // MARK: - Toolbar Components (Overlay Views)  
    @ViewBuilder
    private var liquidGlassToolbar: some View {
        if #available(iOS 26.0, *) {
            LiquidGlassBottomBar(
                thread: thread,
                author: author,
                page: viewModel.currentPage,
                numberOfPages: viewModel.numberOfPages,
                isLoadingViewVisible: viewState.isLoadingSpinnerVisible,
                onSettingsTapped: {
                    viewState.showingSettings = true
                },
                onBackTapped: {
                    withAnimation(.smooth(duration: 0.8)) {
                        viewModel.goToPreviousPage()
                    }
                },
                onForwardTapped: {
                    withAnimation(.smooth(duration: 0.8)) {
                        viewModel.goToNextPage()
                    }
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
                    viewState.showingVoteSheet = true
                },
                onYourPostsTapped: {
                    viewModel.showYourPosts(coordinator: coordinator as? (any MainCoordinator))
                }
            )
        }
    }
    
    @ViewBuilder
    private var standardToolbar: some View {
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
                viewState.showingVoteSheet = true
            },
            onYourPostsTapped: {
                viewModel.showYourPosts(coordinator: coordinator as? (any MainCoordinator))
            }
        )
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
    
    // MARK: - Immersive Mode Scroll Handling (Disabled for Smooth Performance)
    // Immersive mode disabled to prevent constant SwiftUI state updates during scroll
    // Drag-based immersion mode - no timers needed
    private func startImmersionModeIfNeeded() {
        guard postsImmersiveMode else { return }
        // Drag gesture handles immersion mode, no timer needed
        resetToolbarVisibility()
    }
    
    private func stopImmersionMode() {
        // Reset toolbar visibility when disabling immersion mode
        resetToolbarVisibility()
        
        // Reset all drag-related state
        dragState = .idle
        lastDragTranslation = 0
        lastTransitionTime = Date.distantPast
    }
    
    private func checkScrollStateForImmersion() {
        // Currently using manual toggle via double-tap for testing
        // This will be replaced with proper WebView scroll delegate integration
        // when the WebView scroll events are connected to the velocity tracker
    }
    
    private func resetToolbarVisibility() {
        // Reset both navbar and toolbar visibility when page changes with natural spring animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
            isToolbarVisible = true
            isNavigationBarVisible = true
        }
    }
    
    // MARK: - Helper Methods
    private func handleViewAppear() {
        handleViewAppearCallCount += 1
        print("🚀 SwiftUIPostsPageView: handleViewAppear (call #\(handleViewAppearCallCount)) - ViewModel[\(viewModel.debugInstanceID)]: webViewContentWasRestored=\(viewModel.webViewContentWasRestored), posts.count: \(viewModel.posts.count), isLoading: \(viewModel.isLoading)")
        
        // Reset scroll attempt flag for new page load
        hasAttemptedInitialScroll = false
        
        // Initialize toolbar visibility for immersive mode
        if postsImmersiveMode {
            resetToolbarVisibility()
            startImmersionModeIfNeeded()
        }
        
        // Restore complete state first (includes scroll position and jump targets)
        restoreCompleteState()
        
        // Set scroll target from initialization state if provided
        if let jumpToPostID = viewState.pendingJumpToPostID, scrollTarget == nil {
            scrollTarget = .specificPost(jumpToPostID)
            print("🎯 Set initial scroll target from pendingJumpToPostID: \(jumpToPostID)")
        }
        
        // SwiftUI-native approach - no need to check container content
        if !viewModel.posts.isEmpty && !viewModel.isLoading {
            print("🔵 SwiftUIPostsPageView: Posts available, attempting initial scrolling")
            // If posts are already loaded, attempt initial scrolling
            handleInitialScrolling(posts: viewModel.posts)
        } else if viewModel.posts.isEmpty && !viewModel.isLoading {
            print("🔍 COORDINATION DEBUG: ViewModel[\(viewModel.debugInstanceID)]: webViewContentWasRestored=\(viewModel.webViewContentWasRestored), specificPageToLoad=\(String(describing: viewState.specificPageToLoad))")
            if viewModel.webViewContentWasRestored {
                print("🔧 SwiftUIPostsPageView: WebView content was restored - triggering data-only reload")
                // WebView has content, but we need the posts data in the ViewModel
                // Since the WebView coordinator has already preserved the content,
                // trigger forceContentRerender to populate posts data
                viewModel.forceContentRerender()
                viewState.specificPageToLoad = nil
            } else if let specificPage = viewState.specificPageToLoad {
                // Load the specific page that was requested
                print("🔵 SwiftUIPostsPageView: Loading specific page: \(specificPage)")
                // Always mark as read when viewing threads from bookmarks
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
        print("🔵 SwiftUIPostsPageView handleViewDisappear called for thread: \(thread.title ?? "unknown")")
        print("🔵 Thread bookmarked: \(thread.bookmarked)")
        
        viewState.resetPullStates()
        invalidateHandoff()
        
        // Stop immersion mode to prevent memory leaks
        stopImmersionMode()
        
        // Save complete state for comprehensive restoration
        saveCompleteState()
        
        // Also save current scroll position for backward compatibility
        saveScrollPosition()
        
        // Notify bookmarks view to refresh if this thread was bookmarked
        if thread.bookmarked {
            print("🔵 Posting BookmarkViewShouldRefresh notification")
            NotificationCenter.default.post(name: Notification.Name("BookmarkViewShouldRefresh"), object: nil)
        }
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
        // Environment removed - theme used directly
    }
    
    private func handleScrollToFraction(_ fraction: CGFloat?) {
        if let fraction = fraction {
            // Use the new SwiftUI-native scroll coordinator
            let fractionalPoint = CGPoint(x: 0, y: fraction)
            scrollCoordinator.scrollToFractionalOffset(fractionalPoint)
            viewModel.scrollToFraction = nil
        }
    }
    
    private func handlePostsChanged(_ posts: [Post]) {
        print("📋 Posts changed: count=\(posts.count), jumpToPostID=\(viewModel.jumpToPostID ?? "nil")")
        
        // Check if we have a pending jumpToPostID that can now be executed
        if let jumpToPostID = viewModel.jumpToPostID,
           posts.contains(where: { $0.postID == jumpToPostID }) {
            print("🎯 Posts loaded and jumpToPostID \(jumpToPostID) found on current page, will scroll after rendering")
            
            // Delay the scroll to ensure webview has finished rendering the posts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎯 Executing delayed scroll to post \(jumpToPostID)")
                scrollCoordinator.jumpToPost(jumpToPostID)
            }
            
            viewModel.jumpToPostID = nil  // Clear it after scheduling the scroll
            return  // Don't do normal initial scrolling since we're jumping to a specific post
        }
        
        // Use simplified scroll management approach (mirroring UIKit)
        handleInitialScrolling(posts: posts)
    }
    
    private func handleJumpToPostIDChanged(_ postID: String?) {
        print("🎯 jumpToPostID changed to: \(postID ?? "nil")")
        
        guard let postID = postID, !viewModel.posts.isEmpty else {
            print("🎯 No postID or no posts loaded yet, skipping scroll")
            return
        }
        
        // Check if the post is on the current page
        if viewModel.posts.contains(where: { $0.postID == postID }) {
            print("🎯 Post \(postID) found on current page, scrolling to it")
            scrollCoordinator.jumpToPost(postID)
            viewModel.jumpToPostID = nil  // Clear it after handling
        } else {
            print("🎯 Post \(postID) not found on current page, keeping jumpToPostID for when page loads")
        }
    }
    
    // MARK: - Loading View
    var loadingView: some View {
        SwiftUILoadingViewFactory.loadingView(for: theme)
    }
    
    // MARK: - Frog Animation Properties
    var frogOpacity: CGFloat {
        return viewModel.isLastPage ? 1.0 : 0.0
    }
    
    var frogScale: CGFloat {
        return viewModel.isLastPage ? 1.0 : 0.8
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
    // findRenderViewContainer method removed - using SwiftUI-native scroll coordinator instead
    
    // MARK: - Post Navigation
    // attemptPostJump method removed - using SwiftUI-native scroll coordinator instead
    
    
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
        guard handoffEnabled else { 
            print("🤝 Handoff disabled, skipping setup")
            return 
        }
        
        print("🤝 Setting up handoff for thread: \(thread.title ?? "Unknown")")
        
        let activity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
        activity.title = thread.title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = false
        
        if let currentPage = viewModel.currentPage {
            let route: AwfulRoute
            if let author = author {
                route = .threadPageSingleUser(threadID: thread.threadID, userID: author.userID, page: currentPage, .noseen)
                print("🤝 Handoff route: thread page for user \(author.username ?? "Unknown") on page \(currentPage)")
            } else {
                route = .threadPage(threadID: thread.threadID, page: currentPage, .noseen)
                print("🤝 Handoff route: thread page \(currentPage)")
            }
            activity.route = route
        }
        
        // Store the activity for later invalidation
        currentUserActivity = activity
        
        // In SwiftUI, we need to find a way to set this on the hosting view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            setUserActivity(activity, on: rootViewController)
        }
    }
    
    private func setUserActivity(_ activity: NSUserActivity, on viewController: UIViewController) {
        // Find the appropriate view controller to set the user activity on
        if let navigationController = viewController as? UINavigationController {
            navigationController.topViewController?.userActivity = activity
            print("🤝 Set handoff activity on navigation controller's top view controller")
        } else if let hostingController = viewController.children.first(where: { $0 is UIHostingController<AnyView> }) {
            hostingController.userActivity = activity
            print("🤝 Set handoff activity on hosting controller")
        } else {
            viewController.userActivity = activity
            print("🤝 Set handoff activity on root view controller")
        }
    }
    
    func invalidateHandoff() {
        guard let activity = currentUserActivity else { 
            print("🤝 No handoff activity to invalidate")
            return 
        }
        
        print("🤝 Invalidating handoff activity")
        activity.invalidate()
        currentUserActivity = nil
        
        // Also clear it from the view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            clearUserActivity(from: rootViewController)
        }
    }
    
    private func clearUserActivity(from viewController: UIViewController) {
        if let navigationController = viewController as? UINavigationController {
            navigationController.topViewController?.userActivity = nil
        } else if let hostingController = viewController.children.first(where: { $0 is UIHostingController<AnyView> }) {
            hostingController.userActivity = nil
        } else {
            viewController.userActivity = nil
        }
        print("🤝 Cleared handoff activity from view controller")
    }
    
    // MARK: - State Restoration
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
    
    @State private var lastSavedScrollFraction: CGFloat = 0
    @State private var lastScrollSaveTime: Date = Date()
    
    /// Saves state periodically during scrolling to prevent loss of progress
    private func saveStateIfNeeded() {
        let now = Date()
        let timeSinceLastSave = now.timeIntervalSince(lastScrollSaveTime)
        let scrollDifference = abs(viewState.currentScrollFraction - lastSavedScrollFraction)
        
        // Save if significant scroll change (> 5%) or time elapsed (> 10 seconds)
        if scrollDifference > 0.05 || timeSinceLastSave > 10 {
            saveCompleteState()
            self.lastSavedScrollFraction = viewState.currentScrollFraction
            self.lastScrollSaveTime = now
            print("💾 Periodic state save triggered - scroll diff: \(scrollDifference), time: \(timeSinceLastSave)s")
        }
    }
    
    /// Enhanced state restoration for SwiftUI that matches UIKit's approach
    private func saveCompleteState() {
        guard let coordinator = coordinator as? MainCoordinatorImpl else { return }
        
        // Create a comprehensive state dictionary
        var stateData: [String: Any] = [:]
        
        // Core thread and author information
        stateData["threadID"] = thread.threadID
        if let author = author {
            stateData["authorID"] = author.userID
            stateData["authorUsername"] = author.username
        }
        
        // Current page information
        if let currentPage = viewModel.currentPage {
            switch currentPage {
            case .specific(let pageNumber):
                stateData["pageNumber"] = pageNumber
            case .last:
                stateData["pageType"] = "last"
            case .nextUnread:
                stateData["pageType"] = "nextUnread"
            }
            // Note: rawValue is not accessible, using string representation instead
            stateData["pageDescription"] = String(describing: currentPage)
        }
        
        // Scroll position
        stateData["scrollFraction"] = viewState.currentScrollFraction
        
        // View state
        stateData["isImmersiveMode"] = postsImmersiveMode
        stateData["showingSettings"] = viewState.showingSettings
        stateData["timestamp"] = Date().timeIntervalSince1970
        
        // Jump to post ID if pending
        if let jumpToPostID = viewModel.jumpToPostID {
            stateData["pendingJumpToPostID"] = jumpToPostID
        }
        
        print("💾 saveCompleteState: Saved comprehensive state for thread '\(thread.title ?? "Unknown")'")
        coordinator.saveViewState(for: thread.threadID, state: stateData)
    }
    
    private func restoreCompleteState() {
        guard let coordinator = coordinator as? MainCoordinatorImpl else { return }
        
        guard let stateData = coordinator.getViewState(for: thread.threadID) else {
            print("📱 restoreCompleteState: No saved state found for thread '\(thread.title ?? "Unknown")'")
            return
        }
        
        print("📱 restoreCompleteState: Restoring state for thread '\(thread.title ?? "Unknown")'")
        
        // Check if we're loading unread posts (.nextUnread page)
        let isLoadingUnreadPosts = viewState.specificPageToLoad == .nextUnread
        
        // Check timestamp to see if state is stale
        var isStateStale = false
        if let timestamp = stateData["timestamp"] as? TimeInterval {
            let age = Date().timeIntervalSince1970 - timestamp
            isStateStale = age > 300 // 5 minutes
            if isStateStale {
                print("⏰ Saved state is \(Int(age))s old, considered stale")
            }
        }
        
        // Priority-based scroll target restoration (mirroring UIKit approach)
        // Priority 1: Pending jump to post (highest priority)
        if let jumpToPostID = stateData["pendingJumpToPostID"] as? String {
            scrollTarget = .specificPost(jumpToPostID)
            viewState.pendingJumpToPostID = jumpToPostID
            print("📱 Set scroll target: specificPost(\(jumpToPostID))")
            return
        }
        
        // Priority 2: Fresh state restoration (only if not unread and not stale)
        if !isLoadingUnreadPosts && !isStateStale {
            if let scrollFraction = stateData["scrollFraction"] as? CGFloat {
                scrollTarget = .fraction(scrollFraction)
                viewState.pendingScrollFraction = scrollFraction
                print("📱 Set scroll target: fraction(\(scrollFraction))")
                return
            }
        }
        
        // Priority 3: Default for unread posts
        if isLoadingUnreadPosts {
            scrollTarget = .firstUnread
            print("📱 Set scroll target: firstUnread")
            return
        }
        
        // No scroll target needed
        print("📱 No scroll target set - will use default behavior")
        
        // Restore page information (if needed for validation)
        if let pageNumber = stateData["pageNumber"] as? Int {
            print("📱 Restored page number: \(pageNumber)")
        } else if let pageType = stateData["pageType"] as? String {
            print("📱 Restored page type: \(pageType)")
        }
    }
    
    
    // MARK: - Loading Spinner Management
    /// Updates loading spinner visibility based on both loading and scrolling completion
    private func updateLoadingSpinnerVisibility() {
        let shouldShowSpinner = viewModel.isLoading || !isScrollingComplete
        viewState.isLoadingSpinnerVisible = shouldShowSpinner
        print("🔄 Loading spinner visibility: \(shouldShowSpinner) (loading: \(viewModel.isLoading), scrollingComplete: \(isScrollingComplete))")
    }
    
    /// Marks scrolling as complete and updates spinner visibility
    private func markScrollingComplete() {
        isScrollingComplete = true
        updateLoadingSpinnerVisibility()
        print("✅ Scrolling marked as complete")
    }
    
    // MARK: - Simplified Initial Scrolling (UIKit-inspired)
    /// Handles initial scrolling with clear priorities and one-time execution, mirroring UIKit approach
    private func handleInitialScrolling(posts: [Post]) {
        // Only attempt once per page load
        guard !hasAttemptedInitialScroll else {
            print("🎯 handleInitialScrolling: Already attempted for this page load")
            // Mark scrolling as complete if already attempted
            markScrollingComplete()
            return
        }
        
        guard !posts.isEmpty else {
            print("🎯 handleInitialScrolling: No posts available yet")
            // Mark scrolling as complete if no posts to scroll to
            markScrollingComplete()
            return
        }
        
        print("🎯 handleInitialScrolling: Starting with scrollTarget: \(String(describing: scrollTarget))")
        hasAttemptedInitialScroll = true
        
        // Execute scroll target based on priority
        switch scrollTarget {
        case .specificPost(let postID):
            print("🎯 Priority 1: Jumping to specific post: \(postID)")
            // Use the new SwiftUI-native scroll coordinator
            scrollCoordinator.jumpToPost(postID)
            viewModel.jumpToPostID = nil  // Clear it immediately since we handled it
            // Mark scrolling as complete after delay for post jump animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.markScrollingComplete()
            }
            
        case .fraction(let scrollFraction):
            print("🎯 Priority 2: Restoring scroll position: \(scrollFraction)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.viewModel.scrollToFraction = scrollFraction
                self.viewState.pendingScrollFraction = nil
                // Mark scrolling as complete after scroll restoration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.markScrollingComplete()
                }
            }
            
        case .lastPost:
            print("🎯 Priority 3: Jumping to last post")
            // Scroll to the end of the content
            scrollCoordinator.scrollToFractionalOffset(CGPoint(x: 0, y: 1.0))
            // Mark scrolling as complete after delay for scroll animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.markScrollingComplete()
            }
            
        case .firstUnread:
            print("🎯 Priority 4: Scrolling to top with navigation bar offset")
            // Use the same navigation bar offset logic as post jumping, with delay for content rendering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scrollCoordinator.scrollToTopWithNavBarOffset()
                // Mark scrolling as complete after additional delay for scroll animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.markScrollingComplete()
                }
            }
            viewState.pendingScrollFraction = nil
            
        case .none:
            print("🎯 No scroll target - scrolling to top with navigation bar offset")
            // Use the same navigation bar offset logic as post jumping, with delay for content rendering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scrollCoordinator.scrollToTopWithNavBarOffset()
                // Mark scrolling as complete after additional delay for scroll animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.markScrollingComplete()
                }
            }
        }
        
        // Clear the scroll target after execution
        scrollTarget = nil
    }
    
    
}


// MARK: - Pull Control Overlays (temporarily removed for performance testing)
/*
/// Niggly pull control overlay that appears when pulling from top
private struct NigglyPullOverlay: View {
    // Temporarily removed for performance testing
}

/// Arrow pull control overlay for navigating to next page
private struct ArrowPullOverlay: View {
    // Temporarily removed for performance testing
}
*/













// MARK: - Supporting Types
// No longer needed - using isPresented binding instead of item binding

// MARK: - SwiftUI Image Viewer
// SwiftUIImageViewer is now defined in ImageViewController.swift


// MARK: - Preview
#Preview {
    Text("SwiftUIPostsPageView Preview")
        .environment(\.theme, Theme.defaultTheme())
}
