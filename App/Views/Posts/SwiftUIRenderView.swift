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

/// SwiftUI wrapper for RenderView that provides proper state management
struct SwiftUIRenderView: UIViewRepresentable {
    // MARK: - Dependencies
    @ObservedObject var viewModel: PostsPageViewModel
    let theme: Theme
    let onPostAction: (Post, CGRect) -> Void
    let onUserAction: (Post, CGRect) -> Void
    let onScrollChanged: ((Bool) -> Void)?
    let onPullChanged: ((CGFloat) -> Void)?
    let onRefreshTriggered: (() -> Void)?
    let onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)? // offset, contentHeight, viewHeight
    
    // MARK: - Content Insets
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    
    // MARK: - Immersive Mode
    var isImmersiveMode: Bool = false
    
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
        let container = RenderViewContainer()
        container.delegate = context.coordinator
        container.scrollDelegate = context.coordinator
        container.setup(theme: theme)
        return container
    }
    
    func updateUIView(_ container: RenderViewContainer, context: UIViewRepresentableContext<SwiftUIRenderView>) {
        // Update theme stylesheet in case it changed
        container.setup(theme: theme)
        
        // Update frog setting on container
        container.updateFrogAndGhostEnabled(frogAndGhostEnabled)
        
        // Update immersive mode setting
        container.updateImmersiveMode(isImmersiveMode)
        
        // Update content insets based on toolbar visibility
        container.updateContentInsets(top: topInset, bottom: bottomInset)
        
        // Only render posts if we actually have posts to display
        if !viewModel.posts.isEmpty {
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
                loggedInUsername: loggedInUsername
            )
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(
            onPostAction: onPostAction,
            onUserAction: onUserAction,
            viewModel: viewModel,
            onScrollChanged: onScrollChanged,
            onPullChanged: onPullChanged,
            onRefreshTriggered: onRefreshTriggered,
            onScrollPositionChanged: onScrollPositionChanged
        )
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, RenderViewDelegate, RenderViewScrollDelegate {
        let onPostAction: (Post, CGRect) -> Void
        let onUserAction: (Post, CGRect) -> Void
        let onScrollChanged: ((Bool) -> Void)?
        let onPullChanged: ((CGFloat) -> Void)?
        let onRefreshTriggered: (() -> Void)?
        let onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?
        weak var viewModel: PostsPageViewModel?
        private lazy var oEmbedFetcher = OEmbedFetcher()
        
        init(onPostAction: @escaping (Post, CGRect) -> Void, 
             onUserAction: @escaping (Post, CGRect) -> Void,
             viewModel: PostsPageViewModel,
             onScrollChanged: ((Bool) -> Void)? = nil,
             onPullChanged: ((CGFloat) -> Void)? = nil,
             onRefreshTriggered: (() -> Void)? = nil,
             onScrollPositionChanged: ((CGFloat, CGFloat, CGFloat) -> Void)? = nil) {
            self.onPostAction = onPostAction
            self.onUserAction = onUserAction
            self.viewModel = viewModel
            self.onScrollChanged = onScrollChanged
            self.onPullChanged = onPullChanged
            self.onRefreshTriggered = onRefreshTriggered
            self.onScrollPositionChanged = onScrollPositionChanged
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
            // Handle legacy button taps if needed
        }
        
        func didTapLink(to url: URL, in view: RenderView) {
            // Handle link taps using the same logic as UIKit version
            logger.info("Link tapped: \(url)")
            
            // Try to handle as internal route first
            if let route = try? AwfulRoute(url) {
                AppDelegate.instance.open(route: route)
                return
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
            logger.warning("Render process terminated, resetting render state")
            if let container = view.superview as? RenderViewContainer {
                container.resetRenderState()
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
                onPostAction(post, message.frame)
                
            case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
                guard message.postIndex < viewModel.posts.count else { return }
                let post = viewModel.posts[message.postIndex]
                onUserAction(post, message.frame)
                
            default:
                logger.error("Unhandled message: \(type(of: message))")
            }
        }
        
        // MARK: - RenderViewScrollDelegate
        func didScroll(isScrollingUp: Bool) {
            onScrollChanged?(isScrollingUp)
        }
        
        func didPull(fraction: CGFloat) {
            onPullChanged?(fraction)
        }
        
        func didTriggerRefresh() {
            onRefreshTriggered?()
        }
        
        func didUpdateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat) {
            onScrollPositionChanged?(offset, contentHeight, viewHeight)
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
    }
}

// MARK: - Scroll Delegate Protocol
protocol RenderViewScrollDelegate: AnyObject {
    func didScroll(isScrollingUp: Bool)
    func didPull(fraction: CGFloat)
    func didTriggerRefresh()
    func didUpdateScrollPosition(offset: CGFloat, contentHeight: CGFloat, viewHeight: CGFloat)
}

// MARK: - RenderView Container
class RenderViewContainer: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let _renderView = RenderView()
    var renderView: RenderView { _renderView }
    weak var delegate: RenderViewDelegate? {
        didSet {
            _renderView.delegate = delegate
        }
    }
    weak var scrollDelegate: RenderViewScrollDelegate?
    private var lastScrollOffset: CGFloat = 0
    private var lastRenderedPostsHash: Int = 0
    fileprivate var isCurrentlyRendering: Bool = false
    private var frogAndGhostEnabled: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupRenderView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRenderView()
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
    
    func setup(theme: Theme) {
        _renderView.setThemeStylesheet(theme[string: "postsViewCSS"] ?? "")
        
        // Apply scroll indicator style from theme
        _renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
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
        loggedInUsername: String?
    ) {
        // Create a hash of the current rendering state to prevent unnecessary re-renders
        let currentPostsHash = posts.map { $0.postID }.joined().hashValue
        
        // Skip rendering if we're already rendering the same posts or if we're currently in a render operation
        guard currentPostsHash != lastRenderedPostsHash && !isCurrentlyRendering else {
            logger.info("Skipping render - already rendered these \(posts.count) posts or render in progress")
            return
        }
        
        isCurrentlyRendering = true
        lastRenderedPostsHash = currentPostsHash
        logger.info("Rendering \(posts.count) posts")
        
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
    }
    
    func updateContentInsets(top: CGFloat, bottom: CGFloat) {
        let scrollView = _renderView.scrollView
        var currentInsets = scrollView.contentInset
        
        // Only update if insets have changed to avoid unnecessary layout
        if currentInsets.top != top || currentInsets.bottom != bottom {
            currentInsets.top = top
            currentInsets.bottom = bottom
            scrollView.contentInset = currentInsets
            
            // Update scroll indicator insets to match
            scrollView.scrollIndicatorInsets = currentInsets
            
            logger.info("Updated content insets: top=\(top), bottom=\(bottom)")
        }
    }
    
    func updateFrogAndGhostEnabled(_ enabled: Bool) {
        frogAndGhostEnabled = enabled
        logger.info("Updated frogAndGhostEnabled: \(enabled)")
    }
    
    func updateImmersiveMode(_ enabled: Bool) {
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
        
        // Pass scroll position to SwiftUI
        scrollDelegate?.didUpdateScrollPosition(
            offset: currentOffset,
            contentHeight: contentHeight,
            viewHeight: viewHeight
        )
        
        // Calculate pull-to-refresh progress when overscrolling at bottom
        if frogAndGhostEnabled {
            let bottomOffset = currentOffset + viewHeight
            let overscroll = bottomOffset - contentHeight
            
            if overscroll > 0 {
                // User is overscrolling at the bottom - calculate pull fraction
                let maxPullDistance: CGFloat = 80 // Distance needed for full pull
                let pullFraction = min(overscroll / maxPullDistance, 1.0)
                scrollDelegate?.didPull(fraction: pullFraction)
                
                // Trigger refresh if pull is complete and user has dragged far enough
                if pullFraction >= 1.0 && overscroll > maxPullDistance {
                    scrollDelegate?.didTriggerRefresh()
                }
            } else if currentOffset + viewHeight >= contentHeight - 10 {
                // Reset pull progress when very close to or at bottom
                scrollDelegate?.didPull(fraction: 0.0)
            }
        }
        
        // Use a smaller threshold for more responsive toolbar show/hide
        // but include velocity to prevent jittery behavior
        let threshold: CGFloat = 5
        let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView)
        let isSignificantScroll = abs(scrollDiff) > threshold || abs(velocity.y) > 100
        
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
        if !decelerate {
            // If scroll view won't decelerate, reset tracking for next gesture
            lastScrollOffset = scrollView.contentOffset.y
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Reset tracking when scroll animation ends
        lastScrollOffset = scrollView.contentOffset.y
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
            let elements = await _renderView.interestingElements(at: location)
            
            // Use URLMenuPresenter to handle the interesting elements
            let didPresentMenu = URLMenuPresenter.presentInterestingElements(
                elements, 
                from: hostingVC, 
                renderView: _renderView
            )
            
            if !didPresentMenu {
                logger.info("No interesting elements found at long press location")
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
        return true
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
            // Note: Frog JSON removed - using SwiftUI frog instead
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

