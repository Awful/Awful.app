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
    @State private var showingSettings = false
    @State private var showingPagePicker = false
    @State private var messageViewController: MessageComposeViewController?
    @State private var replyWorkspace: IdentifiableReplyWorkspace?
    @State private var currentScrollFraction: CGFloat = 0.0
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil, coordinator: AnyObject? = nil, scrollFraction: CGFloat? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
        
        // Set up scroll restoration if provided
        if let scrollFraction = scrollFraction {
            // We need to set this after initialization
            let viewModel = self._viewModel.wrappedValue
            DispatchQueue.main.async {
                viewModel.scrollToFraction = scrollFraction
            }
        }
    }
    
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage = .specific(1), coordinator: AnyObject? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Full-screen background that extends into all safe areas
            Color(theme[uicolor: "postsViewBackgroundColor"] ?? .systemBackground)
                .ignoresSafeArea(postsImmersiveMode ? .all : .container)
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                // Loading state
                loadingView
            } else {
                // Main content - webview with overlay frog positioned more naturally
                ZStack {
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
                            // Update frog pull progress for SwiftUI frog animation
                            scrollState.handlePullChanged(fraction: fraction, isLastPage: viewModel.isLastPage)
                        },
                        onRefreshTriggered: {
                            // Handle refresh trigger from frog animation
                            if pullForNext {
                                viewModel.goToNextPage()
                            } else {
                                viewModel.refresh()
                            }
                        },
                        onScrollPositionChanged: { offset, contentHeight, viewHeight in
                            // Update scroll position state with throttling
                            scrollState.handleScrollPositionChanged(offset: offset, contentHeight: contentHeight, viewHeight: viewHeight)
                            
                            // Track current scroll fraction for state restoration
                            if contentHeight > 0 {
                                currentScrollFraction = (offset + viewHeight/2) / contentHeight
                            }
                        },
                        replyWorkspace: $replyWorkspace,
                        topInset: scrollState.topInset,
                        bottomInset: scrollState.bottomInset,
                        isImmersiveMode: postsImmersiveMode
                    )
                    .ignoresSafeArea(postsImmersiveMode ? .all : .container)
                    
                    // TODO: SwiftUI frog implementation - temporarily removed for build
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(postsImmersiveMode ? !scrollState.isTopBarVisible : false)
        .onChange(of: scrollState.isTopBarVisible) { newValue in
            // Top bar visibility changed
        }
        .navigationTitle(thread.title ?? "Thread")
        .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
        .overlay(alignment: .top) {
            // Top subtoolbar overlay - appears when scrolling up after scrolling down
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
                .padding(.top, postsImmersiveMode ? 0 : 0) // No padding needed - subtoolbar should be right under navigation bar
                .transition(.opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: scrollState.isSubToolbarVisible)
            }
        }
        .overlay(alignment: .bottom) {
            // Bottom toolbar overlay - shows/hides based on scroll in immersive mode, always visible when not immersive
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
                .padding(.bottom, postsImmersiveMode ? 0 : 0) // No padding needed - toolbar should be at bottom edge
            }
            // No title in immersion mode
        }
        .overlay(alignment: .center) {
            // Main throbber for page loading transitions with full screen overlay
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
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                viewModel.loadInitialPage()
            }
            setupHandoff()
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            isLoadingSpinnerVisible = isLoading
        }
        .onDisappear {
            scrollState.reset()
            invalidateHandoff()
            
            // Save current scroll position for potential restoration
            saveScrollPosition()
        }
        .sheet(item: $replyWorkspace) { identifiableWorkspace in
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
        .sheet(isPresented: $showingSettings) {
            PostsPageSettingsView()
                .environment(\.theme, theme)
        }
        .onChange(of: viewModel.jumpToPostID) { postID in
            if let postID = postID {
                // Find the render view container and jump to the post
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    findRenderViewContainer(in: window)?.jumpToPost(identifiedBy: postID)
                }
                viewModel.jumpToPostID = nil
            }
        }
        .onChange(of: viewModel.scrollToFraction) { fraction in
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
