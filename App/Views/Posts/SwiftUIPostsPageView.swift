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
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    // MARK: - Settings
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    
    // MARK: - UI State
    @State private var scrollPosition: CGFloat = 0
    @State private var isTopBarVisible: Bool = true  // Navigation bar
    @State private var isSubToolbarVisible: Bool = false  // Parent Forum bar
    @State private var isBottomBarVisible: Bool = true
    @State private var hasScrolledDown: Bool = false
    @State private var isLoadingSpinnerVisible: Bool = false
    @State private var scrollContentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var isNearBottom: Bool = false
    @State private var frogPullProgress: CGFloat = 0
    @State private var showingSettings = false
    @State private var showingPagePicker = false
    @State private var messageViewController: MessageComposeViewController?
    @State private var replyWorkspace: IdentifiableReplyWorkspace?
    @State private var selectedPost: Post?
    @State private var selectedUser: User?
    @State private var actionSheetRect: CGRect = .zero
    
    // MARK: - Initialization
    init(thread: AwfulThread, author: User? = nil, coordinator: AnyObject? = nil) {
        self.thread = thread
        self.author = author
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: PostsPageViewModel(thread: thread, author: author))
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
                .ignoresSafeArea(.all)
            
            if viewModel.isLoading && viewModel.posts.isEmpty {
                // Loading state
                loadingView
            } else {
                // Main content - webview gets full height with overlaid frog
                ZStack {
                    SwiftUIRenderView(
                        viewModel: viewModel,
                        theme: theme,
                        onPostAction: handlePostAction,
                        onUserAction: handleUserAction,
                        onScrollChanged: { isScrollingUp in
                            // Handle scroll for bar visibility
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if isScrollingUp {
                                    // Scrolling up - show bars if user has scrolled down first
                                    if hasScrolledDown && !isTopBarVisible {
                                        isTopBarVisible = true
                                    }
                                    if hasScrolledDown && !isSubToolbarVisible {
                                        isSubToolbarVisible = true
                                    }
                                    if !isBottomBarVisible {
                                        isBottomBarVisible = true
                                    }
                                } else {
                                    // Scrolling down - hide bars for immersive reading
                                    hasScrolledDown = true
                                    if isTopBarVisible {
                                        isTopBarVisible = false
                                    }
                                    if isSubToolbarVisible {
                                        isSubToolbarVisible = false
                                    }
                                    if isBottomBarVisible {
                                        isBottomBarVisible = false
                                    }
                                }
                            }
                        },
                        onPullChanged: { fraction in
                            // Update frog pull progress for SwiftUI frog animation
                            frogPullProgress = fraction
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
                            // Update scroll position state
                            scrollPosition = offset
                            scrollContentHeight = contentHeight
                            scrollViewHeight = viewHeight
                            
                            // Check if we're near the bottom
                            let bottomOffset = offset + viewHeight
                            isNearBottom = contentHeight > 0 && bottomOffset >= contentHeight - 100
                            
                            // Calculate frog pull progress for bottom pulls on last page
                            if viewModel.isLastPage && isNearBottom {
                                let overscroll = max(0, bottomOffset - contentHeight)
                                let maxPull: CGFloat = 100
                                frogPullProgress = min(overscroll / maxPull, 1.0)
                            } else {
                                frogPullProgress = 0
                            }
                        },
                        topInset: isSubToolbarVisible ? 40 : 0, // Estimated subtoolbar height
                        bottomInset: isBottomBarVisible ? 100 : 20 // Larger bottom inset when toolbar visible, small padding when hidden
                    )
                    
                    // SwiftUI frog positioned at bottom of content
                    if frogAndGhostEnabled && viewModel.isLastPage {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                SwiftUIFrogAnimation(
                                    theme: theme,
                                    pullProgress: frogPullProgress,
                                    isVisible: isNearBottom,
                                    onRefreshTriggered: {
                                        if pullForNext {
                                            viewModel.goToNextPage()
                                        } else {
                                            viewModel.refresh()
                                        }
                                    }
                                )
                                .frame(width: 40, height: 40)
                                .offset(y: calculateFrogOffset())
                                Spacer()
                            }
                            .padding(.bottom, isBottomBarVisible ? 120 : 40)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isTopBarVisible ? .visible : .hidden, for: .navigationBar)
        .navigationTitle(thread.title ?? "Thread")
        .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
        .overlay(alignment: .top) {
            // Top subtoolbar overlay
            if isSubToolbarVisible {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .bottom) {
            // Bottom toolbar overlay
            if isBottomBarVisible {
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            // No title in immersion mode
        }
        .overlay(alignment: .center) {
            // Main throbber for page loading transitions with full screen overlay
            if isLoadingSpinnerVisible {
                ZStack {
                    // Semi-transparent overlay to dim content
                    Color(theme[uicolor: "postsLoadingViewTintColor"] ?? .systemBackground)
                        .opacity(1)
                        .ignoresSafeArea()
                    
                    // Main throbber animation
                    MainThrobberView(theme: theme)
                    
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
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoadingSpinnerVisible = isLoading
            }
        }
        .onDisappear {
            invalidateHandoff()
        }
        .sheet(item: $replyWorkspace) { workspace in
            NavigationView {
                Text("Reply Workspace")
                    .navigationTitle("Reply")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                replyWorkspace = nil
                            }
                        }
                    }
            }
        }
        .overlay {
            if let post = selectedPost {
                PostActionsMenu(
                    post: post,
                    sourceRect: actionSheetRect,
                    viewModel: viewModel,
                    onDismiss: { selectedPost = nil },
                    replyWorkspace: $replyWorkspace
                )
            }
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
        VStack {
            ProgressView()
                .scaleEffect(1.5)
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
    
    private func calculateFrogOffset() -> CGFloat {
        // Calculate frog position based on scroll position to make it appear embedded in content
        let totalContentHeight = scrollContentHeight
        let viewHeight = scrollViewHeight
        let currentOffset = scrollPosition
        
        // Position frog near the bottom of the content
        let bottomContentY = totalContentHeight - viewHeight
        let frogBaseOffset = max(0, bottomContentY - currentOffset)
        
        // Add some bounce effect when overscrolling
        let overscroll = max(0, currentOffset + viewHeight - totalContentHeight)
        let bounceOffset = min(overscroll * 0.5, 30)
        
        return -(frogBaseOffset + bounceOffset)
    }
    
    // MARK: - Action Handlers
    func handlePostAction(_ post: Post, rect: CGRect) {
        selectedPost = post
        actionSheetRect = rect
    }
    
    func handleUserAction(_ post: Post, rect: CGRect) {
        selectedUser = post.author
        actionSheetRect = rect
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
    
    
    // MARK: - Action Buttons
    @ViewBuilder
    var postActionButtons: some View {
        if let post = selectedPost {
            Button("Reply") {
                viewModel.replyToPost(post) { workspace in
                    replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                }
                selectedPost = nil
            }
            
            Button("Quote") {
                viewModel.quotePost(post) { workspace in
                    replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                }
                selectedPost = nil
            }
            
            if post.editable {
                Button("Edit") {
                    viewModel.editPost(post) { workspace in
                        replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                    }
                    selectedPost = nil
                }
            }
            
            Button("Mark as Read Up To Here") {
                viewModel.markAsReadUpTo(post)
                selectedPost = nil
            }
            
            Button("Copy Post URL") {
                viewModel.copyPostURL(post)
                selectedPost = nil
            }
        }
    }
}

// MARK: - PostActionsMenu
struct PostActionsMenu: View {
    let post: Post
    let sourceRect: CGRect
    let viewModel: PostsPageViewModel
    let onDismiss: () -> Void
    @Binding var replyWorkspace: IdentifiableReplyWorkspace?
    
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background to capture taps - use a very light overlay
            Rectangle()
                .fill(Color.black.opacity(0.001))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }
                .allowsHitTesting(true)
            
            // Context menu
            VStack(spacing: 0) {
                ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                    Button(action: item.action) {
                        HStack(spacing: 12) {
                            Image(systemName: item.systemImage)
                                .foregroundColor(.primary)
                                .frame(width: 20)
                            
                            Text(item.title)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index != menuItems.count - 1 {
                        Divider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
            .frame(width: 250)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .position(x: min(max(sourceRect.midX, 125), UIScreen.main.bounds.width - 125), 
                     y: sourceRect.maxY + 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-dismiss after 10 seconds if no interaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if isVisible {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { _ in
                    // Dismiss on scroll/drag
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }
        )
    }
    
    private var menuItems: [PostMenuItem] {
        var items: [PostMenuItem] = [
            PostMenuItem(title: "Reply", systemImage: "arrowshape.turn.up.left") {
                viewModel.replyToPost(post) { workspace in
                    replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                }
                onDismiss()
            },
            PostMenuItem(title: "Quote", systemImage: "quote.bubble") {
                viewModel.quotePost(post) { workspace in
                    replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                }
                onDismiss()
            }
        ]
        
        if post.editable {
            items.append(PostMenuItem(title: "Edit", systemImage: "pencil") {
                viewModel.editPost(post) { workspace in
                    replyWorkspace = IdentifiableReplyWorkspace(workspace: workspace)
                }
                onDismiss()
            })
        }
        
        items.append(contentsOf: [
            PostMenuItem(title: "Mark as Read Up To Here", systemImage: "checkmark.circle") {
                viewModel.markAsReadUpTo(post)
                onDismiss()
            },
            PostMenuItem(title: "Copy Post URL", systemImage: "doc.on.doc") {
                viewModel.copyPostURL(post)
                onDismiss()
            }
        ])
        
        return items
    }
}

// MARK: - PostMenuItem
struct PostMenuItem {
    let title: String
    let systemImage: String
    let action: () -> Void
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
                .frame(width: 20, height: 20) // Much smaller frog
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

// MARK: - Main Throbber for Page Loading
private struct MainThrobberView: UIViewRepresentable {
    let theme: Theme
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let animationView = LottieAnimationView(
            animation: LottieAnimation.named("mainthrobber60"),
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Apply theme colors
        let color = ColorValueProvider(theme["activityIndicatorColor"]?.lottieColorValue ?? UIColor.systemBlue.lottieColorValue)
        let keypath = AnimationKeypath(keys: ["**", "**", "**", "Color"])
        animationView.setValueProvider(color, keypath: keypath)
        
        // Add the animation view to container and constrain it
        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            animationView.widthAnchor.constraint(equalToConstant: 80),
            animationView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        animationView.play()
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the LottieAnimationView in the container and update theme colors if needed
        if let animationView = uiView.subviews.first as? LottieAnimationView {
            let color = ColorValueProvider(theme["activityIndicatorColor"]?.lottieColorValue ?? UIColor.systemBlue.lottieColorValue)
            let keypath = AnimationKeypath(keys: ["**", "**", "**", "Color"])
            animationView.setValueProvider(color, keypath: keypath)
        }
    }
}



// MARK: - Preview
#Preview {
    let thread = AwfulThread()
    thread.title = "Sample Thread"
    thread.bookmarked = false
    
    return NavigationView {
        SwiftUIPostsPageView(thread: thread)
            .environment(\.theme, Theme.defaultTheme())
    }
}
