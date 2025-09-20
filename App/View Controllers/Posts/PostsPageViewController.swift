//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import MobileCoreServices
import MRProgress
import os
import UIKit
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageViewController")

/// Shows a list of posts in a thread.
@MainActor
final class PostsPageViewController: ViewController {
    var selectedPost: Post? = nil
    var selectedUser: User? = nil
    var selectedFrame: CGRect? = nil
    private var advertisementHTML: String?
    private let author: User?
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.embedBlueskyPosts) private var embedBlueskyPosts
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private var flagRequest: Task<Void, Error>?
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var jumpToLastPost = false
    @FoilDefaultStorageOptional(Settings.lastOfferedPasteboardURLString) private var lastOfferedPasteboardURLString
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    var postIndex: Int = 0
    @FoilDefaultStorage(Settings.jumpToPostEndOnDoubleTap) private var jumpToPostEndOnDoubleTap
    private var jumpToPostIDAfterLoading: String?
    private var messageViewController: MessageComposeViewController?
    private var networkOperation: Task<Void, Never>?
    private var observers: [NSKeyValueObservation] = []
    private lazy var oEmbedFetcher: OEmbedFetcher = .init()
    private(set) var page: ThreadPage?
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    private var replyWorkspace: ReplyWorkspace?
    private var restoringState = false
    private var scrollToFractionAfterLoading: CGFloat?
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    let thread: AwfulThread
    private var webViewDidLoadOnce = false

    // this is to overcome not being allowed to mark stored properties as potentially unavailable using @available
    private var _liquidGlassTitleView: UIView?

    @available(iOS 26.0, *)
    private var liquidGlassTitleView: LiquidGlassTitleView? {
        if _liquidGlassTitleView == nil {
            _liquidGlassTitleView = LiquidGlassTitleView()
        }
        return _liquidGlassTitleView as? LiquidGlassTitleView
    }

    /// Updates the title view text color based on scroll position for dynamic adaptation
    @available(iOS 26.0, *)
    func updateTitleViewTextColorForScrollProgress(_ progress: CGFloat) {
        if progress < 0.01 {
            // At top: use theme color
            liquidGlassTitleView?.textColor = theme["navigationBarTextColor"]
        } else if progress > 0.99 {
            // Fully scrolled: use nil for dynamic color adaptation
            liquidGlassTitleView?.textColor = nil
        }
    }

    func threadActionsMenu() -> UIMenu {
        return UIMenu(title: thread.title ?? "", image: nil, identifier: nil, options: .displayInline, children: [
            // Bookmark
            UIAction(
                title: thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread",
                image: UIImage(named: thread.bookmarked ? "remove-bookmark" : "add-bookmark")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("bookmark"),
                attributes: thread.bookmarked ? .destructive : [],
                handler: { [unowned self] in bookmark(action: $0) }
            ),
            // Copy link
            UIAction(
                title: "Copy link",
                image: UIImage(named: "copy-url")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("copyLink"),
                handler: { [unowned self] in copyLink(action: $0) }
            ),
            // Vote
            UIAction(
                title: "Vote",
                image: UIImage(named: "vote")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("vote"),
                handler: { [unowned self] in vote(action: $0) }
            ),
            // Your posts
            UIAction(
                title: "Your posts",
                image: UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("yourPosts"),
                handler: { [unowned self] in yourPosts(action: $0) }
            ),
        ])
    }

    private var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }

    private lazy var postsView: PostsPageView = {
        let postsView = PostsPageView()
        postsView.didStartRefreshing = { [weak self] in
            self?.loadNextPageOrRefresh()
        }
        postsView.renderView.delegate = self
        postsView.renderView.registerMessage(FYADFlagRequest.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidTapPostActionButton.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.FetchOEmbedFragment.self)
        postsView.topBar.goToParentForum = { [unowned self] in
            guard let forum = self.thread.forum else { return }
            AppDelegate.instance.open(route: .forum(id: forum.forumID))
        }
        return postsView
    }()

    /// A hidden button that we misuse to show a proper iOS context menu on tap (as opposed to long-tap).
    private lazy var hiddenMenuButton: HiddenMenuButton = {
        let postActionButton = HiddenMenuButton()
        postActionButton.alpha = 0
        if #available(iOS 16.0, *) {
            postActionButton.preferredMenuElementOrder = .fixed
        }
        postsView.addSubview(postActionButton)
        return postActionButton
    }()
    private class HiddenMenuButton: UIButton {
        init() {
            super.init(frame: .zero)
            showsMenuAsPrimaryAction = true

            if #available(iOS 16.0, *) {
                preferredMenuElementOrder = .fixed
            }
            // Set the interface style to follow the theme
            updateInterfaceStyle()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func show(menu: UIMenu, from rect: CGRect) {
            frame = rect
            self.menu = menu
            
            // Update interface style before showing the menu to ensure it uses the correct theme
            updateInterfaceStyle()
            
            // Use the original approach that was working, but ensure we get iOS 26 styling
            // This finds the internal touch-down gesture recognizer and manually triggers it
            gestureRecognizers?.first { "\(type(of: $0))".contains("TouchDown") }?.touchesBegan([], with: .init())
        }
        
        func updateInterfaceStyle() {
            // Follow the theme's menuAppearance setting for menu appearance
            let menuAppearance = Theme.defaultTheme()[string: "menuAppearance"]
            overrideUserInterfaceStyle = menuAppearance == "light" ? .light : .dark
        }
    }

    private struct FYADFlagRequest: RenderViewMessage {
        static let messageName = "fyadFlagRequest"

        init?(rawMessage: WKScriptMessage, in renderView: RenderView) {
            assert(rawMessage.name == FYADFlagRequest.messageName)
        }
    }

    /**
        - parameter thread: The thread whose posts are shown.
        - parameter author: An optional author used to filter the shown posts. May be nil, in which case all posts are shown.
     */
    init(thread: AwfulThread, author: User? = nil) {
        self.thread = thread
        self.author = author
        super.init(nibName: nil, bundle: nil)

        restorationClass = type(of: self)

        navigationItem.rightBarButtonItem = composeItem

        hidesBottomBarWhenPushed = true
    }

    deinit {
        networkOperation?.cancel()
    }

    var posts: [Post] = []

    var numberOfPages: Int {
        if let author = author {
            return Int(thread.filteredNumberOfPagesForAuthor(author))
        } else {
            return Int(thread.numberOfPages)
        }
    }

    override var theme: Theme {
        guard let forum = thread.forum, !forum.forumID.isEmpty else {
            return Theme.defaultTheme()
        }
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }

    override var title: String? {
        didSet {
            if #available(iOS 26.0, *) {
                let glassView = liquidGlassTitleView
                glassView?.title = title
                glassView?.textColor = theme["navigationBarTextColor"]

                // Set font based on device type
                switch UIDevice.current.userInterfaceIdiom {
                case .pad:
                    glassView?.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPad"]!)!.weight)
                default:
                    glassView?.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPhone"]!)!.weight)
                }

                navigationItem.titleView = glassView
                // Configure navigation bar for liquid glass effect
                configureNavigationBarForLiquidGlass()
            } else {
                navigationItem.titleView = nil
                navigationItem.titleLabel.text = title
            }
        }
    }

    /**
        Changes the page.

        - parameter page: The page to load.
        - parameter updateCache: Whether to fetch posts from the client, or simply render any posts that are cached.
        - parameter updateLastReadPost: Whether to advance the "last-read post" marker on the Forums.
     */
    func loadPage(
        _ newPage: ThreadPage,
        updatingCache: Bool,
        updatingLastReadPost updateLastReadPost: Bool
    ) {
        flagRequest?.cancel()
        flagRequest = nil
        networkOperation?.cancel()
        networkOperation = nil

        // prevent white flash caused by webview being opaque during refreshes
        if darkMode {
            postsView.renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: false)
            postsView.viewHasBeenScrolledOnce = false
        }

        // Clear the post or fractional offset to scroll to. It's assumed that whatever calls this will
        // take care of re-establishing where to scroll to after calling loadPage().
        jumpToPostIDAfterLoading = nil
        scrollToFractionAfterLoading = nil
        jumpToLastPost = false

        // SA: When filtering the thread by a single user, the "goto=lastpost" redirect ignores the user filter, so we'll do our best to guess.
        var newPage = newPage
        if let author = author, case .last? = page {
            newPage = .specific(Int(thread.filteredNumberOfPagesForAuthor(author)))
        }

        let reloadingSamePage = page == newPage
        page = newPage

        if posts.isEmpty || !reloadingSamePage {
            postsView.endRefreshing()

            updateUserInterface()

            if !restoringState {
                hiddenPosts = 0
            }

            refetchPosts()

            if !posts.isEmpty {
                renderPosts()
            }
        }

        let renderedCachedPosts = !posts.isEmpty

        updateUserInterface()

        configureUserActivityIfPossible()

        if !updatingCache {
            clearLoadingMessage()
            return
        }

        let initialTheme = theme

        let fetch = Task {
            try await ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: newPage, updateLastReadPost: updateLastReadPost)
        }
        // Store a type-erased cancellation handle to avoid Sendable issues
        networkOperation = Task {
            _ = await fetch.result
        }
        Task { [weak self] in
            do {
                let (posts, firstUnreadPost, _) = try await fetch.value
                guard let self else { return }

                // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
                guard self.page == newPage else { return }

                if self.theme != initialTheme {
                    self.themeDidChange()
                }

                if !posts.isEmpty {
                    self.posts = posts

                    let anyPost = posts[0]
                    if self.author != nil {
                        self.page = .specific(anyPost.singleUserPage)
                    } else {
                        self.page = .specific(anyPost.page)
                    }
                }

                switch newPage {
                case .last where self.posts.isEmpty,
                     .nextUnread where self.posts.isEmpty:
                    let pageCount = self.numberOfPages > 0 ? "\(self.numberOfPages)" : "?"
                    if #available(iOS 26.0, *) {
                        self.verticalPageNumberView.currentPage = 0
                        self.verticalPageNumberView.totalPages = self.numberOfPages > 0 ? self.numberOfPages : 0
                    } else {
                        self.currentPageItem.title = "Page ? of \(pageCount)"
                    }

                case .last, .nextUnread, .specific:
                    break
                }

                self.configureUserActivityIfPossible()

                if self.hiddenPosts == 0, let firstUnreadPost = firstUnreadPost, firstUnreadPost > 0 {
                    self.hiddenPosts = firstUnreadPost - 1
                }

                if reloadingSamePage || renderedCachedPosts {
                    self.scrollToFractionAfterLoading = self.postsView.renderView.scrollView.fractionalContentOffset.y
                }

                self.renderPosts()

                self.updateUserInterface()

                if let lastPost = self.posts.last, updateLastReadPost {
                    if self.thread.seenPosts < lastPost.threadIndex {
                        self.thread.seenPosts = lastPost.threadIndex
                    }
                }

                self.postsView.endRefreshing()
            } catch {
                guard let self else { return }

                // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
                if self.page != newPage { return }

                await MainActor.run {
                    self.clearLoadingMessage()

                    if case .archivesRequired = error as? AwfulCoreError {
                        let alert = UIAlertController(title: "Archives Required", error: error)
                        self.present(alert, animated: true)
                    } else {
                        let offlineMode = (error as NSError).domain == NSURLErrorDomain && (error as NSError).code != NSURLErrorCancelled
                        if self.posts.isEmpty || !offlineMode {
                            let alert = UIAlertController(title: "Could Not Load Page", error: error)
                            self.present(alert, animated: true)
                        }
                    }
                    
                    switch newPage {
                    case .last where self.posts.isEmpty,
                         .nextUnread where self.posts.isEmpty:
                        let pageCount = self.numberOfPages > 0 ? "\(self.numberOfPages)" : "?"
                        if #available(iOS 26.0, *) {
                            // Use vertical view: show unknown current page with known total
                            self.verticalPageNumberView.currentPage = 0 // Will display as "?"
                            self.verticalPageNumberView.totalPages = self.numberOfPages > 0 ? self.numberOfPages : 0
                            // iOS 26+ handles colors automatically
                        } else {
                            self.currentPageItem.title = "Page ? of \(pageCount)"
                        }

                    case .last, .nextUnread, .specific:
                        break
                    }
                }
            }
        }
    }

    /// Scroll the posts view so that a particular post is visible (if the post is on the current(ly loading) page).
    func scrollPostToVisible(_ post: Post) {
        let i = posts.firstIndex(of: post)
        if postsView.loadingView != nil || !webViewDidLoadOnce || i == nil {
            jumpToPostIDAfterLoading = post.postID
        } else {
            if let i = i , i < hiddenPosts {
                showHiddenSeenPosts()
            }

            postsView.renderView.jumpToPost(identifiedBy: post.postID)
        }
    }

    func goToLastPost() {
        loadPage(.last, updatingCache: true, updatingLastReadPost: true)
        jumpToLastPost = true
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    // IMPORTANT: The updateLastReadPost parameter must be passed through to renderPostsAsync
    // to ensure thread.seenPosts is updated AFTER PostRenderModels are created.
    // This prevents posts from incorrectly appearing as "seen" on first view.
    private func renderPosts(updateLastReadPost: Bool = false) {
        webViewDidLoadOnce = false

        Task { @MainActor in
            await renderPostsAsync(updateLastReadPost: updateLastReadPost)
        }
    }
    
    private func renderPostsAsync(updateLastReadPost: Bool) async {
        var context: [String: Any] = [:]

        context["stylesheet"] = theme[string: "postsViewCSS"] as Any

        if self.posts.count > self.hiddenPosts {
            let subset = self.posts[self.hiddenPosts...]
            // IMPORTANT: Create PostRenderModels BEFORE updating thread.seenPosts
            // This ensures posts maintain their correct seen/unseen status when rendered
            context["posts"] = subset.map { PostRenderModel($0).context }
            
            // Update thread.seenPosts AFTER creating PostRenderModels but BEFORE rendering HTML
            // This prevents a race condition where posts would incorrectly appear as "seen"
            if let lastPost = self.posts.last, updateLastReadPost {
                if self.thread.seenPosts < lastPost.threadIndex {
                    self.thread.seenPosts = lastPost.threadIndex
                }
            }
        }

        if let ad = self.advertisementHTML, !ad.isEmpty {
            context["advertisementHTML"] = ad
        }

        if context["posts"] != nil, case .specific(let pageNumber)? = self.page, pageNumber >= self.numberOfPages {
            context["endMessage"] = true
        }

        context["enableFrogAndGhost"] = self.frogAndGhostEnabled

        context["ghostJsonData"] = try? String(contentsOf: URL(string: "ghost60.json", relativeTo: Bundle.main.resourceURL)!, encoding: .utf8)

        if let loggedInUsername = self.loggedInUsername, !loggedInUsername.isEmpty {
            context["loggedInUsername"] = loggedInUsername
        }

        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet

        if !self.thread.threadID.isEmpty {
            context["threadID"] = self.thread.threadID
        }

        if let forum = self.thread.forum, !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }

        context["tweetTheme"] = self.theme[string: "postsTweetTheme"] ?? "light"

        let html: String
        do {
            html = try StencilEnvironment.shared.renderTemplate(.postsView, context: context)
        } catch {
            logger.error("could not render posts view HTML: \(error)")
            html = ""
        }

        await self.postsView.renderView.eraseDocument()
        self.postsView.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
    }

    private lazy var composeItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(compose))
        item.accessibilityLabel = NSLocalizedString("compose.accessibility-label", comment: "")
        // Only set explicit tint color for iOS < 26
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle the color automatically
        } else {
            item.tintColor = theme["navigationBarTextColor"]
        }
        return item
    }()

    @IBAction private func compose(
        _ sender: UIBarButtonItem,
        forEvent event: UIEvent
    ) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        var isLongPress: Bool {
            event.allTouches?.first?.tapCount == 0
        }
        func makeNewReplyWorkspace() {
            replyWorkspace = ReplyWorkspace(thread: thread)
            replyWorkspace!.completion = replyCompletionBlock
        }
        func presentReply() {
            present(replyWorkspace!.viewController, animated: true)
        }

        switch replyWorkspace?.status {
        case .editing:
            presentDraftMenu(
                from: .barButtonItem(sender),
                options: .init(
                    continueEditing: presentReply,
                    deleteDraft: {
                        makeNewReplyWorkspace()
                        presentReply()
                    })
            )

        case .replying where isLongPress:
            presentDraftMenu(
                from: .barButtonItem(sender),
                options: .init(
                    continueEditing: presentReply,
                    deleteDraft: makeNewReplyWorkspace)
            )

        case .replying:
            presentReply()

        case nil:
            makeNewReplyWorkspace()
            presentReply()
        }
    }

    @objc private func newReply(_ sender: UIKeyCommand) {
        if replyWorkspace == nil {
            replyWorkspace = ReplyWorkspace(thread: thread)
            replyWorkspace?.completion = replyCompletionBlock
        }
        present(replyWorkspace!.viewController, animated: true, completion: nil)
    }

    private var replyCompletionBlock: (_ result: ReplyWorkspace.CompletionResult) -> Void {
        return { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .forgetAboutIt:
                self.replyWorkspace = nil

            case .posted:
                self.replyWorkspace = nil
                self.loadPage(.nextUnread, updatingCache: true, updatingLastReadPost: true)

            case .saveDraft:
                break
            }

            self.dismiss(animated: true)
        }
    }

    private lazy var settingsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(
            image: UIImage(named: "page-settings"),
            handler: { [unowned self] action in
                let settings = PostsPageSettingsViewController()
                self.present(settings, animated: true)

                if let popover = settings.popoverPresentationController {
                    popover.barButtonItem = action.sender as? UIBarButtonItem
                }
            }
        ))
        item.accessibilityLabel = "Settings"
        // Only set explicit tint color for iOS < 26
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle the color automatically
        } else {
            item.tintColor = theme["toolbarTextColor"]
        }
        return item
    }()

    private lazy var backItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(
            image: UIImage(named: "arrowleft"),
            handler: { [unowned self] action in
                guard case .specific(let pageNumber)? = self.page, pageNumber > 1 else { return }
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                self.loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
            }
        ))
        item.accessibilityLabel = "Previous page"
        // Only set explicit tint color for iOS < 26
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle the color automatically
        } else {
            item.tintColor = theme["toolbarTextColor"]
        }
        return item
    }()

    private lazy var verticalPageNumberView: VerticalPageNumberView = {
        let view = VerticalPageNumberView()
        view.onTap = { [weak self] in
            self?.handlePageNumberTap()
        }
        return view
    }()
    
    private lazy var currentPageItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction { [unowned self] action in
            guard self.postsView.loadingView == nil else { return }
            let selectotron = Selectotron(postsViewController: self)
            self.present(selectotron, animated: true)

            if let popover = selectotron.popoverPresentationController {
                popover.barButtonItem = action.sender as? UIBarButtonItem
            }
        })
        
        // Set up the bar button item based on iOS version
        if #available(iOS 26.0, *) {
            // Use vertical page number view for modern appearance wrapped in container for centering
            let containerView = UIView()
            containerView.addSubview(verticalPageNumberView)
            verticalPageNumberView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                verticalPageNumberView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                verticalPageNumberView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                containerView.widthAnchor.constraint(equalTo: verticalPageNumberView.widthAnchor, constant: 6), // 3 points padding on each side
                // Add a bit of vertical padding so the content appears visually centered in the toolbar
                containerView.heightAnchor.constraint(equalTo: verticalPageNumberView.heightAnchor, constant: 5)
            ])
            item.customView = containerView
        } else {
            // Use traditional text title for iOS 18 and below
            item.possibleTitles = ["2345 / 2345"]
        }
        
        item.accessibilityHint = "Opens page picker"
        return item
    }()

    private lazy var forwardItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(
            image: UIImage(named: "arrowright"),
            handler: { [unowned self] action in
                guard case .specific(let pageNumber)? = self.page, pageNumber < self.numberOfPages, pageNumber > 0 else { return }
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                self.loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
            }
        ))
        item.accessibilityLabel = "Next page"
        // Only set explicit tint color for iOS < 26
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle the color automatically
        } else {
            item.tintColor = theme["toolbarTextColor"]
        }
        return item
    }()


    private func actionsItem() -> UIBarButtonItem {
        // Use primaryAction like the other toolbar buttons
        let item = UIBarButtonItem(primaryAction: UIAction(
            image: UIImage(named: "steamed-ham"),
            handler: { [unowned self] action in
                if self.enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                // Get the sender and find its frame
                if let barButtonItem = action.sender as? UIBarButtonItem,
                   let view = barButtonItem.value(forKey: "view") as? UIView {
                    let buttonFrameInView = view.convert(view.bounds, to: self.view)
                    self.hiddenMenuButton.show(menu: self.threadActionsMenu(), from: buttonFrameInView)
                } else {
                    // Fallback position
                    let frame = CGRect(x: self.view.bounds.width - 60, y: self.view.bounds.height - 100, width: 44, height: 44)
                    self.hiddenMenuButton.show(menu: self.threadActionsMenu(), from: frame)
                }
            }
        ))
        item.accessibilityLabel = "Thread actions"
        // Only set explicit tint color for iOS < 26
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle the color automatically
        } else {
            item.tintColor = theme["toolbarTextColor"]
        }
        return item
    }

    private func refetchPosts() {
        guard case .specific(let pageNumber)? = page else {
            posts = []
            return
        }

        let request = Post.makeFetchRequest()

        let indexKey = author == nil ? "threadIndex" : "filteredThreadIndex"
        let predicate = NSPredicate(format: "thread = %@ AND %d <= %K AND %K <= %d", thread, (pageNumber - 1) * 40 + 1, indexKey, indexKey, pageNumber * 40)
        if let author = author {
            let restOfPredicate = NSPredicate(format: "author.userID = %@", author.userID)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, restOfPredicate])
        } else {
            request.predicate = predicate
        }

        request.sortDescriptors = [NSSortDescriptor(key: indexKey, ascending: true)]

        guard let context = thread.managedObjectContext else { fatalError("where's the context") }
        do {
            posts = try context.fetch(request)
        } catch {
            print("\(#function) error fetching posts: \(error)")
        }
    }

    private func updateUserInterface() {
        title = thread.title?.collapsingWhitespace()

        if page == .last || page == .nextUnread || posts.isEmpty {
            showLoadingView()
        }

        postsView.topBar.showPreviousPosts = hiddenPosts == 0 ? nil : { [unowned self] in
            self.showHiddenSeenPosts()
        }
        postsView.topBar.scrollToEnd = posts.isEmpty ? nil : { [unowned self] in
            self.scrollToBottom(nil)
        }

        if pullForNext {
            if case .specific(let pageNumber)? = page, numberOfPages > pageNumber {
                if !(postsView.refreshControl is PostsPageRefreshArrowView) {
                    postsView.refreshControl = PostsPageRefreshArrowView()
                }
            } else {
                if !(postsView.refreshControl is PostsPageRefreshSpinnerView) {
                    if !frogAndGhostEnabled {
                        postsView.refreshControl = PostsPageRefreshSpinnerView()
                    } else {
                        postsView.refreshControl = GetOutFrogRefreshSpinnerView(theme: theme)
                    }
                }
            }
        } else {
            postsView.refreshControl = nil
        }

        backItem.isEnabled = {
            switch page {
            case .specific(let pageNumber)?:
                return pageNumber > 1
            case .last?, .nextUnread?, nil:
                return false
            }
        }()

        if case .specific(let pageNumber)? = page, numberOfPages > 0 {
            // Update page display based on iOS version
            if #available(iOS 26.0, *) {
                // Use vertical page number view for modern appearance
                verticalPageNumberView.currentPage = pageNumber
                verticalPageNumberView.totalPages = numberOfPages
                // iOS 26+ handles colors automatically
                currentPageItem.accessibilityLabel = "Page \(pageNumber) of \(numberOfPages)"
            } else {
                // Use traditional text title for iOS 18 and below
                currentPageItem.title = "\(pageNumber) / \(numberOfPages)"
                currentPageItem.accessibilityLabel = "Page \(pageNumber) of \(numberOfPages)"
                currentPageItem.setTitleTextAttributes([.font: UIFont.preferredFontForTextStyle(.body, weight: .regular)], for: .normal)
            }
        } else {
            // Clear page display
            if #available(iOS 26.0, *) {
                verticalPageNumberView.currentPage = 0
                verticalPageNumberView.totalPages = 0
            } else {
                currentPageItem.title = ""
            }
            currentPageItem.accessibilityLabel = nil
        }

        forwardItem.isEnabled = {
            switch page {
            case .specific(let pageNumber)?:
                return pageNumber < numberOfPages
            case .last?, .nextUnread?, nil:
                return false
            }
        }()

        composeItem.isEnabled = !thread.closed
        
        // Update toolbar items based on liquid glass setting and button states
        updateToolbarItems()
    }
    
    private func updateToolbarItems() {
        var toolbarItems: [UIBarButtonItem] = [settingsItem, .flexibleSpace()]
        
        // Add navigation buttons - always show all buttons to maintain consistent spacing
        toolbarItems.append(contentsOf: [backItem, currentPageItem, forwardItem])
        
        toolbarItems.append(contentsOf: [.flexibleSpace(), actionsItem()])
        postsView.toolbarItems = toolbarItems
    }

    private func showLoadingView() {
        guard postsView.loadingView == nil else { return }
        postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
    }

    private func clearLoadingMessage() {
        postsView.loadingView = nil
    }

    private func loadNextPageOrRefresh() {
        guard let page = page else { return }

        let nextPage: ThreadPage

        // There's surprising sublety in figuring out what "next page" means.
        if posts.count < 40 {
            // When we're showing a partial page, just fill in the rest by reloading the current page.
            nextPage = page
        } else if page == .specific(numberOfPages) {
            // When we've got a full page but we're not sure there's another, just reload. The next page arrow will light up if we've found more pages. This is pretty subtle and not at all ideal. (Though doing something like going to the next unread page is even more confusing!)
            nextPage = page
        } else if case .specific(let pageNumber) = page {
            // Otherwise we know there's another page, so fire away.
            nextPage = .specific(pageNumber + 1)
        } else {
            return
        }

        loadPage(nextPage, updatingCache: true, updatingLastReadPost: true)
    }

    @objc func currentPageButtonTapped(_ sender: UIBarButtonItem) {
        guard self.postsView.loadingView == nil else { return }
        let selectotron = Selectotron(postsViewController: self)
        self.present(selectotron, animated: true, completion: nil)

        if let popover = selectotron.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    private func handlePageNumberTap() {
        guard postsView.loadingView == nil else { return }
        let selectotron = Selectotron(postsViewController: self)
        present(selectotron, animated: true)
        
        // For popover presentation with custom view, we need to set sourceView and sourceRect
        if let popover = selectotron.popoverPresentationController {
            popover.sourceView = verticalPageNumberView
            popover.sourceRect = verticalPageNumberView.bounds
        }
    }

    @objc private func loadPreviousPage(_ sender: UIKeyCommand) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard case .specific(let pageNumber)? = page, pageNumber > 1 else { return }
        loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
    }

    @objc private func loadNextPage(_ sender: UIKeyCommand) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard case .specific(let pageNumber)? = page else { return }
        loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
    }

    private func showHiddenSeenPosts() {
        let end = hiddenPosts
        hiddenPosts = 0

        let html = (0..<end).map(renderedPostAtIndex).joined(separator: "\n")
        postsView.renderView.prependPostHTML(html)
    }

    @objc private func scrollToBottom(_ sender: UIKeyCommand?) {
        let scrollView = postsView.renderView.scrollView
        scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 1, width: 1, height: 1), animated: true)
    }

    @objc private func scrollToTop(_ sender: UIKeyCommand?) {
        postsView.renderView.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
    }

    @objc private func scrollUp(_ sender: UIKeyCommand) {
        let scrollView = postsView.renderView.scrollView
        let proposedOffset = max(scrollView.contentOffset.y - 80, 0)
        if proposedOffset > 0 {
            let newOffset = CGPoint(x: scrollView.contentOffset.x, y: proposedOffset)
            scrollView.setContentOffset(newOffset, animated: true)
        } else {
            scrollToTop(nil)
        }
    }

    @objc private func scrollDown(_ sender: UIKeyCommand) {
        let scrollView = postsView.renderView.scrollView
        let proposedOffset = scrollView.contentOffset.y + 80
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom(nil)
        } else {
            let newOffset = CGPoint(x: scrollView.contentOffset.x, y: proposedOffset)
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }

    @objc private func pageUp(_ sender: UIKeyCommand) {
        let scrollView = postsView.renderView.scrollView
        let proposedOffset = scrollView.contentOffset.y - (scrollView.bounds.height - 80)
        let newOffset = CGPoint(x: scrollView.contentOffset.x, y: max(proposedOffset, 0))
        scrollView.setContentOffset(newOffset, animated: true)
    }

    @objc private func pageDown(_ sender: UIKeyCommand) {
        let scrollView = postsView.renderView.scrollView
        let proposedOffset = scrollView.contentOffset.y + (scrollView.bounds.height - 80)
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom(nil)
        } else {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: proposedOffset), animated: true)
        }
    }

    @objc private func didLongPressOnPostsView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        let location = sender.location(in: postsView.renderView)
        Task {
            let elements = await postsView.renderView.interestingElements(at: location)
            _ = URLMenuPresenter.presentInterestingElements(elements, from: self, renderView: self.postsView.renderView)
        }
    }

    @objc private func didDoubleTapOnPostsView(_ sender: UITapGestureRecognizer) {
        Task {
            guard let postFrame = await postsView.renderView.findPostFrame(at: sender.location(in: postsView.renderView)) else {
                return
            }
            let scrollView = postsView.renderView.scrollView
            let scrollFrame = scrollView.convert(postFrame, from: postsView.renderView)
            let belowBottom = CGRect(
                // Maintain the current horizontal position in case user is zoomed in.
                x: scrollView.contentOffset.x,
                y: scrollFrame.maxY - 1,
                width: 1,
                height: 1)
            scrollView.scrollRectToVisible(belowBottom, animated: true)
        }
    }

    private func renderedPostAtIndex(_ i: Int) -> String {
        do {
            let model = PostRenderModel(posts[i])
            return try StencilEnvironment.shared.renderTemplate(.post, context: model)
        } catch {
            logger.error("could not render post at index \(i): \(error)")
            return ""
        }
    }

    private func readIgnoredPostAtIndex(_ i: Int) {
        let post = posts[i]
        Task {
            do {
                try await ForumsClient.shared.readIgnoredPost(post)

                // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
                if let i = posts.firstIndex(of: post) {
                    postsView.renderView.replacePostHTML(renderedPostAtIndex(i), at: i - hiddenPosts)
                }
            } catch {
                let alert = UIAlertController(networkError: error)
                present(alert, animated: true)
            }
        }
    }

    private func didTapUserHeaderWithRect(_ frame: CGRect, forPostAtIndex postIndex: Int) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.selectedPost = posts[postIndex + hiddenPosts]
        self.selectedFrame = frame

        var userActions: [UIMenuElement] = []
        guard let user = self.selectedPost!.author else { return }
        self.selectedUser = user

        let userActionMenu: UIMenu = {
            // Profile
            let profile = UIAction.Identifier("profile")
            let profileAction = UIAction(title: "Profile",
                                         image: UIImage(named: "user-profile")!.withRenderingMode(.alwaysTemplate),
                                         identifier: profile,
                                         handler: profile(action:))
            userActions.append(profileAction)

            // Their posts
            if author == nil {
                let theirPosts = UIAction.Identifier("theirPosts")
                let theirPostsAction = UIAction(title: "Their posts",
                                                image: UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate),
                                                identifier: theirPosts,
                                                handler: theirPosts(action:))
                userActions.append(theirPostsAction)
            }
            // Private Message
            if canSendPrivateMessages &&
                user.canReceivePrivateMessages &&
                user.userID != loggedInUserID
            {
                let privateMessage = UIAction.Identifier("privateMessage")
                let privateMessageAction = UIAction(title: "Private message",
                                                    image: UIImage(named: "send-private-message")!.withRenderingMode(.alwaysTemplate),
                                                    identifier: privateMessage,
                                                    handler: privateMessage(action:))
                userActions.append(privateMessageAction)
            }
            // Rap Sheet
            let rapSheet = UIAction.Identifier("rapSheet")
            let rapSheetAction = UIAction(title: "Rap sheet",
                                          image: UIImage(named: "rap-sheet")!.withRenderingMode(.alwaysTemplate),
                                          identifier: rapSheet,
                                          handler: rapSheet(action:))
            userActions.append(rapSheetAction)

            // Ignore user
            if self.selectedPost!.ignored {
                let ignoreUser = UIAction.Identifier("ignoreUser")
                let ignoreAction = UIAction(title: "Unignore user",
                                            image: UIImage(named: "ignore")!.withRenderingMode(.alwaysTemplate),
                                            identifier: ignoreUser,
                                            handler: ignoreUser(action:))
                userActions.append(ignoreAction)
            } else {
                let ignoreUser = UIAction.Identifier("ignoreUser")
                let ignoreAction = UIAction(title: "Ignore user",
                                            image: UIImage(named: "ignore")!.withRenderingMode(.alwaysTemplate),
                                            identifier: ignoreUser,
                                            handler: ignoreUser(action:))
                userActions.append(ignoreAction)
            }

            let tempMenu = UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: userActions)
            return UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: [tempMenu])
        }()

        hiddenMenuButton.show(menu: userActionMenu, from: frame)
    }

    private func shareURL(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
            var queryItems = [
                URLQueryItem(name: "threadid", value: self.thread.threadID),
                URLQueryItem(name: "perpage", value: "40"),
                URLQueryItem(name: "noseen", value: "1"),
            ]
            if case .specific(let pageNumber)? = self.page, pageNumber > 1 {
                queryItems.append(URLQueryItem(name: "pagenumber", value: "\(pageNumber)"))
            }
            components.queryItems = queryItems
            components.fragment = "post\(self.selectedPost!.postID)"
            let url = components.url!

            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: [SafariActivity(), ChromeActivity(url: url)])
            activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
                if completed && activityType == .copyToPasteboard {
                    self.lastOfferedPasteboardURLString = url.absoluteString
                }
            }
            self.present(activityVC, animated: false)

            if let popover = activityVC.popoverPresentationController {
                // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
                popover.sourceRect = self.selectedFrame!
                popover.sourceView = self.postsView.renderView
            }
        }
    }

    private func markThreadAsSeenUpTo(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            await dismiss(animated: false)
            do {
                try await ForumsClient.shared.markThreadAsSeenUpTo(selectedPost!)
                selectedPost!.thread?.seenPosts = selectedPost!.threadIndex
                postsView.renderView.markReadUpToPost(identifiedBy: selectedPost!.postID)

                let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: LocalizedString("posts-page.marked-read"), mode: .checkmark, animated: true)!
                try? await Task.sleep(timeInterval: 0.7)
                overlay.dismiss(true)
            } catch {
                let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-mark-seen"), error: error)
                present(alert, animated: true)
            }
        }
    }

    private func quote(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        func makeNewReplyWorkspace() {
            self.replyWorkspace = ReplyWorkspace(thread: self.thread)
            self.replyWorkspace?.completion = self.replyCompletionBlock
        }
        func quotePost() {
            Task { @MainActor in
                do {
                    try await replyWorkspace!.quotePost(self.selectedPost!)
                    if let vc = self.replyWorkspace?.viewController {
                        self.present(vc, animated: true)
                    }
                } catch {
                    let alert = UIAlertController(networkError: error)
                    self.present(alert, animated: true)
                }
            }
        }
        self.dismiss(animated: false) {
            switch self.replyWorkspace?.status {
            case .editing:
                self.presentDraftMenu(
                    from: .view(self.postsView.renderView, sourceRect: self.selectedFrame!),
                    options: .init(
                        continueEditing: quotePost,
                        deleteDraft: {
                            makeNewReplyWorkspace()
                            quotePost()
                        })
                )

            case .replying:
                quotePost()

            case nil:
                makeNewReplyWorkspace()
                quotePost()
            }
        }
    }

    private func yourPosts(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) { [self] in

            let userKey = UserKey(
                userID: loggedInUserID!,
                username: loggedInUsername
            )
            let user = User.objectForKey(objectKey: userKey, in: self.thread.managedObjectContext!)

            let postsVC = PostsPageViewController(thread: self.thread, author: user)
            postsVC.restorationIdentifier = "Just your posts"
            postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)

            self.navigationController?.pushViewController(postsVC, animated: true)

        }
    }

    private func bookmark(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            await dismiss(animated: false)
            do {
                try await ForumsClient.shared.setThread(thread, isBookmarked: !thread.bookmarked)
                if isViewLoaded, view.window != nil {
                    let status = thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: status, mode: .checkmark, animated: true)!
                    overlay.tintColor = theme["tintColor"]
                    try? await Task.sleep(timeInterval: 0.7)
                    overlay.dismiss(true)

                    // update toolbar so menu reflects new bookmarked state
                    updateToolbarItems()
                }
            } catch {
                logger.error("error marking thread: \(error)")
            }
        }
    }

    private func copyLink(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) { [self] in
            let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Copied Link", mode: .checkmark, animated: true)
            overlay?.tintColor = theme["tintColor"]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                overlay?.dismiss(true)
            }
            let route: AwfulRoute
            let page = page ?? .first
            if let singleUserID = author?.userID {
                route = .threadPageSingleUser(threadID: thread.threadID, userID: singleUserID, page: page, .noseen)
            } else {
                route = .threadPage(threadID: thread.threadID, page: page, .noseen)
            }
            let url = route.httpURL
            lastOfferedPasteboardURLString = url.absoluteString
            UIPasteboard.general.coercedURL = url
        }
    }

    private func copy(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            await dismiss(animated: false)
            let overlay = MRProgressOverlayView.showOverlayAdded(
                to: postsView.renderView,
                title: LocalizedString("posts-page.copied-post"),
                mode: .checkmark,
                animated: true
            )!
            overlay.tintColor = self.theme["tintColor"]

            do {
                let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: selectedPost!)
                UIPasteboard.general.string = bbcode
            } catch {
                let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-copy-post"), error: error)
                present(alert, animated: true)
            }
            overlay.dismiss(true)
        }
    }

    private func report(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let reportVC = ReportPostViewController(post: self.selectedPost!)

        self.dismiss(animated: false) {
            self.present(reportVC.enclosingNavigationController, animated: true, completion: nil)
        }
    }

    private func findPost(action: UIAction) {
        // This will add the thread to the navigation stack, giving us thread->author->thread.
        AppDelegate.instance.open(route: .post(id: self.selectedPost!.postID, .noseen))
    }

    private func vote(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            await dismiss(animated: false)

            var actions = stride(from: 5, to: 0, by: -1).map { i in
                UIAlertAction.default(title: "\(i)", handler: { [self] in
                    let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: "Voting \(i)", mode: .indeterminate, animated: true)!
                    overlay.tintColor = theme["tintColor"]

                    Task {
                        do {
                            try await ForumsClient.shared.rate(thread, as: i)

                            overlay.mode = .checkmark
                            try? await Task.sleep(timeInterval: 0.7)
                            overlay.dismiss(true)
                        } catch {
                            overlay.dismiss(false)

                            let alert = UIAlertController(title: "Vote Failed", error: error)
                            present(alert, animated: true)
                        }
                    }
                })
            }
            actions.append(.cancel())
            let actionSheet = UIAlertController(actionSheetActions: actions)
            present(actionSheet, animated: false)

            if let popover = actionSheet.popoverPresentationController {
                popover.barButtonItem = actionsItem()
            }
        }
    }

    private func profile(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let profileVC = ProfileViewController(user: self.selectedUser!)

        self.dismiss(animated: false) {
            self.present(profileVC.enclosingNavigationController, animated: true, completion: nil)
        }
    }

    private func theirPosts(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.dismiss(animated: false) {
            let postsVC = PostsPageViewController(thread: self.thread, author: self.selectedUser!)
            postsVC.restorationIdentifier = "Just their posts"
            postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
            self.navigationController?.pushViewController(postsVC, animated: true)
        }
    }

    private func privateMessage(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.dismiss(animated: false) {
            let messageVC = MessageComposeViewController(recipient: self.selectedUser!)
            self.messageViewController = messageVC
            messageVC.delegate = self
            messageVC.restorationIdentifier = "New PM from posts view"
            self.present(messageVC.enclosingNavigationController, animated: true, completion: nil)
        }
    }

    private func rapSheet(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.dismiss(animated: false) {
            let rapSheetVC = RapSheetViewController(user: self.selectedUser!)
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.present(rapSheetVC.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(rapSheetVC, animated: true)
            }
        }
    }

    private func ignoreUser(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            await dismiss(animated: false)
            // removing ignored users requires username. adding a new user requires userid
            guard let userKey = selectedPost!.ignored ? selectedUser!.username : selectedUser!.userID else { return }

            let ignoreBlock: (_ username: String) async throws -> Void

            if selectedPost!.ignored {
                ignoreBlock = ForumsClient.shared.removeUserFromIgnoreList
            } else {
                ignoreBlock = ForumsClient.shared.addUserToIgnoreList
            }

            let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: "Updating Ignore List", mode: .indeterminate, animated: true)!
            overlay.tintColor = self.theme["tintColor"]

            do {
                try await ignoreBlock(userKey)
                overlay.mode = .checkmark
                try? await Task.sleep(timeInterval: 0.7)
                overlay.dismiss(true)
            } catch {
                overlay.dismiss(false)

                let alert = UIAlertController(title: "Could Not Update Ignore List", error: error)
                present(alert, animated: true)
            }
        }
    }

    private func edit(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        func presentNewReplyWorkspace() {
            Task {
                do {
                    let text = try await ForumsClient.shared.findBBcodeContents(of: selectedPost!)
                    let replyWorkspace = ReplyWorkspace(post: selectedPost!, bbcode: text)
                    self.replyWorkspace = replyWorkspace
                    replyWorkspace.completion = replyCompletionBlock
                    present(replyWorkspace.viewController, animated: true)
                } catch {
                    let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-edit-post"), error: error)
                    present(alert, animated: true)
                }
            }
        }

        switch self.replyWorkspace?.status {
        case .editing, .replying:
            self.presentDraftMenu(
                from: .view(self.postsView.renderView, sourceRect: self.selectedFrame!),
                options: .init(deleteDraft: presentNewReplyWorkspace)
            )

        case nil:
            presentNewReplyWorkspace()
        }
    }

    private func didTapActionButtonWithRect(
        _ frame: CGRect,
        forPostAtIndex postIndex: Int
    ) {
        assert(postIndex + hiddenPosts < posts.count, "post \(postIndex) beyond range (hiding \(hiddenPosts) posts")
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.selectedPost = posts[postIndex + hiddenPosts]
        self.selectedFrame = frame

        let postActionMenu: UIMenu = {
            var postActions: [UIAction] = []
            // edit post
            if selectedPost!.editable {
                postActions.append(.init(
                    title: "Edit",
                    image: UIImage(named: "edit-post")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("edit"),
                    handler: edit(action:)
                ))
            }

            // Quote
            if !thread.closed {
                postActions.append(.init(
                    title: "Quote",
                    image: UIImage(named: "quote-post")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("quote"),
                    handler: quote(action:)
                ))
            }

            // Copy post
            if thread.closed {
                postActions.append(.init(
                    title: "Copy",
                    image: UIImage(named: "quote-post")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("copy"),
                    handler: copy(action:)
                ))
            }

            // Mark Read Up To Here
            if author == nil {
                postActions.append(.init(
                    title: "Mark as last read",
                    image: UIImage(named: "mark-read-up-to-here")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("markread"),
                    handler: markThreadAsSeenUpTo(action:)
                ))
            }

            // Find post
            if author != nil {
                postActions.append(.init(
                    title: "Find post",
                    image: UIImage(named: "quick-look")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("find"),
                    handler: findPost(action:)
                ))
            }

            // Share URL
            postActions.append(.init(
                title: "Share",
                image: UIImage(named: "share")!.withRenderingMode(.alwaysTemplate),
                identifier: UIAction.Identifier("shareurl"),
                handler: shareURL(action:)
            ))

            // Report
            postActions.append(.init(
                title: "Report",
                image: UIImage(named: "rap-sheet")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("report"),
                handler: report(action:)
            ))

            return UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: postActions)
        }()

        hiddenMenuButton.show(menu: postActionMenu, from: frame)
    }
    
    private func fetchOEmbed(url: URL, id: String) {
        Task {
            let callbackData = await oEmbedFetcher.fetch(url: url, id: id)
            postsView.renderView.didFetchOEmbed(id: id, response: callbackData)
        }
    }

    private func presentDraftMenu(
        from source: DraftMenuSource,
        options: DraftMenuOptions
    ) {
        let title: String
        switch replyWorkspace?.status {
        case let .editing(post) where post.author?.userID == loggedInUserID:
            title = NSLocalizedString("compose.draft-menu.editing-own-post.title", comment: "")
        case let .editing(post):
            if let username = post.author?.username {
                title = String(format: NSLocalizedString("compose.draft-menu.editing-other-post.title", comment: ""), username)
            } else {
                title = NSLocalizedString("compose.draft-menu.editing-unknown-other-post.title", comment: "")
            }
        case .replying:
            title = NSLocalizedString("compose.draft-menu.replying.title", comment: "")
        case nil:
            return assertionFailure("No reason to show draft menu")
        }

        let actionSheet = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet)
        if let action = options.continueEditing {
            actionSheet.addAction(.init(
                title: NSLocalizedString("compose.draft-menu.continue-editing", comment: ""),
                style: .default,
                handler: { _ in action() }
            ))
        }
        if let action = options.deleteDraft {
            actionSheet.addAction(.init(
                title: NSLocalizedString("compose.draft-menu.delete-draft", comment: ""),
                style: .destructive,
                handler: { _ in action() }
            ))
        }
        actionSheet.addAction(.init(
            title: NSLocalizedString("cancel", comment: ""),
            style: .cancel
        ))
        present(actionSheet, animated: true)

        switch source {
        case let .barButtonItem(item):
            actionSheet.popoverPresentationController?.barButtonItem = item
        case let .view(sourceView, sourceRect: sourceRect):
            actionSheet.popoverPresentationController?.sourceRect = sourceRect
            actionSheet.popoverPresentationController?.sourceView = sourceView
        }
    }

    private struct DraftMenuOptions {
        var continueEditing: (() -> Void)? = nil
        var deleteDraft: (() -> Void)? = nil
    }

    private enum DraftMenuSource {
        case barButtonItem(UIBarButtonItem)
        case view(UIView, sourceRect: CGRect)
    }

    private func fetchNewFlag() {
        flagRequest?.cancel()

        guard let forum = thread.forum else { return }

        flagRequest = Task { [weak self] in
            let flagInfo: RenderView.FlagInfo?
            do {
                let flag = try await ForumsClient.shared.flagForThread(in: forum)
                var components = URLComponents(string: "https://fi.somethingawful.com")!
                components.path = "/flags\(flag.path)"
                if let username = flag.username {
                    components.queryItems = [URLQueryItem(name: "by", value: username)]
                }
                let src = components.url
                flagInfo = src.map { src in
                    let title = String(format: LocalizedString("posts-page.fyad-flag-title"), flag.username ?? "", flag.created ?? "")
                    return RenderView.FlagInfo(src: src, title: title)
                }
            } catch {
                logger.warning("could not fetch FYAD flag: \(error)")
                flagInfo = nil
            }
            self?.postsView.renderView.setFYADFlag(flagInfo)
        }
    }

    private func configureUserActivityIfPossible() {
        guard case .specific? = page, handoffEnabled else {
            userActivity = nil
            return
        }

        userActivity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
        userActivity?.needsSave = true
    }

    override func updateUserActivityState(_ activity: NSUserActivity) {
        guard let page = page, case .specific = page else { return }

        activity.route = author.map {
            .threadPageSingleUser(threadID: thread.threadID, userID: $0.userID, page: page, .seen)
        } ?? .threadPage(threadID: thread.threadID, page: page, .seen)
        activity.title = thread.title

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }

    override func themeDidChange() {
        super.themeDidChange()

        postsView.themeDidChange(theme)
        
        // Update title appearance for iOS 26+
        if #available(iOS 26.0, *) {
            let glassView = liquidGlassTitleView
            // Set both text color and font from theme
            glassView?.textColor = theme["navigationBarTextColor"]

            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                glassView?.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPad"]!)!.weight)
            default:
                glassView?.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPhone"]!)!.weight)
            }

            // Update navigation bar configuration based on new theme
            configureNavigationBarForLiquidGlass()
        } else {
            // Apply theme to regular title label for iOS < 26
            navigationItem.titleLabel.textColor = theme["navigationBarTextColor"]
            
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                navigationItem.titleLabel.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPad"]!)!.weight)
                navigationItem.titleLabel.textColor = Theme.defaultTheme()[uicolor: "navigationBarTextColor"]!
            default:
                navigationItem.titleLabel.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPhone"]!)!.weight)
                navigationItem.titleLabel.numberOfLines = 2
                navigationItem.titleLabel.textColor = Theme.defaultTheme()[uicolor: "navigationBarTextColor"]!
            }
        }
        
        // Update navigation bar button colors (only for iOS < 26)
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle colors automatically
        } else {
            composeItem.tintColor = theme["navigationBarTextColor"]
            // Ensure the navigation bar itself uses the correct tint color for the back button
            navigationController?.navigationBar.tintColor = theme["navigationBarTextColor"]
        }
        
        // Also trigger the navigation controller's theme change to update back button appearance
        if let navController = navigationController as? NavigationController {
            navController.themeDidChange()
        }


        if postsView.loadingView != nil {
            postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
        }

        let appearance = UIToolbarAppearance()
        if (postsView.toolbar.isTranslucent) {
            appearance.configureWithDefaultBackground()
        } else {
            appearance.configureWithOpaqueBackground()
        }
        appearance.backgroundColor = Theme.defaultTheme()["backgroundColor"]!
        appearance.shadowImage = nil
        appearance.shadowColor = nil

        postsView.toolbar.standardAppearance = appearance
        postsView.toolbar.compactAppearance = appearance
        postsView.toolbar.scrollEdgeAppearance = appearance
        postsView.toolbar.compactScrollEdgeAppearance = appearance
        
        // Update toolbar button text colors (only for iOS < 26)
        if #available(iOS 26.0, *) {
            // Let iOS 26+ handle colors automatically
        } else {
            backItem.tintColor = theme["toolbarTextColor"]
            forwardItem.tintColor = theme["toolbarTextColor"]
            settingsItem.tintColor = theme["toolbarTextColor"]
            verticalPageNumberView.textColor = theme["toolbarTextColor"] ?? UIColor.systemBlue
        }
        
        // Update toolbar items to refresh the actions button
        updateToolbarItems()

        messageViewController?.themeDidChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        /*
         Laying this screen out used to be a challenge: there are bars on the top and bottom, and between our old deployment target and the latest SDK we spanned a few different schools of layout thought. This is probably not necessary anymore. But here was the plan:

         1. Turn off all UIKit magic automated everything. We'll handle all scroll view content insets and safe area insets ourselves.
         2. Set layout margins on `postsView` in lieu of the above. Layout margins are available on all iOS versions that Awful supports.

         Here is where we turn off the magic. In `viewDidLayoutSubviews` we update the layout margins.
         */
        extendedLayoutIncludesOpaqueBars = true
        postsView.insetsLayoutMarginsFromSafeArea = false
        postsView.renderView.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(postsView, constrainEdges: .all)

        // Toolbar items will be set by updateToolbarItems() called from updateUserInterface()

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnPostsView))
        longPress.delegate = self
        postsView.renderView.addGestureRecognizer(longPress)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapOnPostsView))
        doubleTap.delegate = self
        doubleTap.numberOfTapsRequired = 2
        postsView.renderView.addGestureRecognizer(doubleTap)
        $jumpToPostEndOnDoubleTap
            .receive(on: RunLoop.main)
            .sink { doubleTap.isEnabled = $0 }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: PostsViewExternalStylesheetLoader.DidUpdateNotification.name,
            object: PostsViewExternalStylesheetLoader.shared
        )
        .map { PostsViewExternalStylesheetLoader.DidUpdateNotification($0)! }
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.postsView.renderView.setExternalStylesheet($0.stylesheet) }
        .store(in: &cancellables)

        $embedBlueskyPosts
            .dropFirst()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.postsView.renderView.embedBlueskyPosts() }
            .store(in: &cancellables)

        $embedTweets
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                if $0 {
                    self.postsView.renderView.embedTweets()
                }
            }
            .store(in: &cancellables)

        $fontScale
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.postsView.renderView.setFontScale($0) }
            .store(in: &cancellables)

        $handoffEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                if $0, self.view.window != nil {
                    self.configureUserActivityIfPossible()
                }
            }
            .store(in: &cancellables)

        $pullForNext
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateUserInterface() }
            .store(in: &cancellables)

        $showAvatars
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.postsView.renderView.setShowAvatars($0) }
            .store(in: &cancellables)

        $showImages
            .dropFirst()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.postsView.renderView.loadLinkifiedImages() }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePostsViewLayoutMargins()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePostsViewLayoutMargins()
    }

    private func updatePostsViewLayoutMargins() {
        // See commentary in `viewDidLoad()` about our layout strategy here. tl;dr layout margins were the highest-level approach available on all versions of iOS that Awful supported, so we'll use them exclusively to represent the safe area. Probably not necessary anymore.
        postsView.layoutMargins = view.safeAreaInsets
    }
    
    @available(iOS 26.0, *)
    private func configureNavigationBarForLiquidGlass() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        guard let navController = navigationController as? NavigationController else { return }

        // Hide the custom bottom border from NavigationBar for liquid glass effect
        if let awfulNavigationBar = navigationBar as? NavigationBar {
            awfulNavigationBar.bottomBorderColor = .clear
        }

        // Start with opaque background - NavigationController will handle the transition to clear on scroll
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        appearance.shadowColor = nil
        appearance.shadowImage = nil

        // Set initial text colors from theme
        let textColor: UIColor = theme["navigationBarTextColor"]!
        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]

        let buttonFont = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
        let buttonAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: buttonFont
        ]
        appearance.buttonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.buttonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.doneButtonAppearance.highlighted.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.normal.titleTextAttributes = buttonAttributes
        appearance.backButtonAppearance.highlighted.titleTextAttributes = buttonAttributes

        // Set the back indicator image with template mode
        if let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }

        // Apply to all states
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance

        // CRITICAL: Set tintColor AFTER applying appearance to ensure back button uses theme color
        let navTextColor: UIColor = theme["navigationBarTextColor"]!
        print("DEBUG: Setting navigationBar.tintColor to: \(navTextColor) for theme: \(theme["name"] ?? "unknown")")
        navigationBar.tintColor = navTextColor

        // Force the navigation controller to start at scroll position 0 (top)
        // This will also update tintColor based on scroll position if needed
        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))

        // Force navigation bar to update its appearance
        navigationBar.setNeedsLayout()
        navigationBar.layoutIfNeeded()

        // Try setting the back button tint directly on the previous view controller
        if let previousVC = navigationController?.viewControllers.dropLast().last {
            previousVC.navigationItem.backBarButtonItem?.tintColor = navTextColor
        }

        // The NavigationController will handle the dynamic transition based on scroll position
        // iOS 26 handles status bar style automatically with liquid glass
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        configureUserActivityIfPossible()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        userActivity = nil
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(thread.objectKey, forKey: Keys.threadKey)
        if let page = page {
            coder.encode(page.nsCoderIntValue, forKey: Keys.page)
        }
        coder.encode(author?.objectKey, forKey: Keys.authorUserKey)
        coder.encode(hiddenPosts, forKey: Keys.hiddenPosts)
        coder.encode(messageViewController, forKey: Keys.messageViewController)
        coder.encode(advertisementHTML, forKey: Keys.advertisementHTML)
        coder.encode(Float(postsView.renderView.scrollView.fractionalContentOffset.y), forKey: Keys.scrolledFractionOfContent)
        coder.encode(replyWorkspace, forKey: Keys.replyWorkspace)
    }

    override func decodeRestorableState(with coder: NSCoder) {
        restoringState = true

        super.decodeRestorableState(with: coder)

        messageViewController = coder.decodeObject(forKey: Keys.messageViewController) as? MessageComposeViewController
        messageViewController?.delegate = self

        hiddenPosts = coder.decodeInteger(forKey: Keys.hiddenPosts)
        let page: ThreadPage = {
            guard
                coder.containsValue(forKey: Keys.page),
                let page = ThreadPage(nsCoderIntValue: coder.decodeInteger(forKey: Keys.page))
                else { return .specific(1) }
            return page
        }()
        self.page = page
        loadPage(page, updatingCache: false, updatingLastReadPost: true)
        if posts.isEmpty {
            loadPage(page, updatingCache: true, updatingLastReadPost: true)
        }

        advertisementHTML = coder.decodeObject(forKey: Keys.advertisementHTML) as? String
        scrollToFractionAfterLoading = CGFloat(coder.decodeFloat(forKey: Keys.scrolledFractionOfContent))

        replyWorkspace = coder.decodeObject(forKey: Keys.replyWorkspace) as? ReplyWorkspace
        replyWorkspace?.completion = replyCompletionBlock
    }

    override func applicationFinishedRestoringState() {
        super.applicationFinishedRestoringState()

        restoringState = false
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ThreadPage {
    init?(nsCoderIntValue: Int) {
        switch nsCoderIntValue {
        case -2:
            self = .last
        case -1:
            self = .nextUnread
        case 1...Int.max:
            self = .specific(nsCoderIntValue)
        default:
            return nil
        }
    }

    var nsCoderIntValue: Int {
        switch self {
        case .last:
            return -2
        case .nextUnread:
            return -1
        case .specific(let pageNumber):
            return pageNumber
        }
    }
}

extension PostsPageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true)
    }
}

extension PostsPageViewController: RenderViewDelegate {
    func didFinishRenderingHTML(in view: RenderView) {
        if embedBlueskyPosts {
            view.embedBlueskyPosts()
        }
        if embedTweets {
            view.embedTweets()
        }

        if frogAndGhostEnabled {
            view.loadLottiePlayer()
        }

        webViewDidLoadOnce = true

        if jumpToLastPost {
            if posts.count > 0 {
                let lastPost = posts.max(by: { (a, b) -> Bool in
                    return a.threadIndex < b.threadIndex
                })
                if let lastPost = lastPost {
                    jumpToPostIDAfterLoading = lastPost.postID
                    jumpToLastPost = false
                }
            }
        }

        if let postID = jumpToPostIDAfterLoading {
            postsView.renderView.jumpToPost(identifiedBy: postID)
        } else if let newFractionalOffset = scrollToFractionAfterLoading {
            var fractionalOffset = postsView.renderView.scrollView.fractionalContentOffset
            fractionalOffset.y = newFractionalOffset
            postsView.renderView.scrollToFractionalOffset(fractionalOffset)
        }

        clearLoadingMessage()
    }

    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
            didTapUserHeaderWithRect(message.frame, forPostAtIndex: message.postIndex)

        case let message as RenderView.BuiltInMessage.DidTapPostActionButton:
            didTapActionButtonWithRect(message.frame, forPostAtIndex: message.postIndex)

        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            if let postID = jumpToPostIDAfterLoading {
                postsView.renderView.jumpToPost(identifiedBy: postID)
            } else if let fraction = scrollToFractionAfterLoading, fraction > 0 {
                var offset = postsView.renderView.scrollView.fractionalContentOffset
                offset.y = fraction
                postsView.renderView.scrollToFractionalOffset(offset)
            }
            
        case let message as RenderView.BuiltInMessage.FetchOEmbedFragment:
            fetchOEmbed(url: message.url, id: message.id)

        case is FYADFlagRequest:
            fetchNewFlag()

        default:
            logger.warning("ignoring unexpected JavaScript message: \(type(of: message).messageName)")
        }
    }

    func didTapLink(to url: URL, in view: RenderView) {
        if let route = try? AwfulRoute(url) {
            if url.fragment == "awful-ignored", case let .post(id: postID, _) = route {
                if let i = posts.firstIndex(where: { $0.postID == postID }) {
                    readIgnoredPostAtIndex(i)
                }
            } else {
                AppDelegate.instance.open(route: route)
            }
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.open(url)
        }
    }

    func renderProcessDidTerminate(in view: RenderView) {
        renderPosts()
    }
}

extension PostsPageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension PostsPageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        let context = AppDelegate.instance.managedObjectContext
        guard let threadKey = coder.decodeObject(forKey: Keys.threadKey) as? ThreadKey else { return nil }
        let thread = AwfulThread.objectForKey(objectKey: threadKey, in: context)
        let userKey = coder.decodeObject(forKey: Keys.authorUserKey) as? UserKey
        let author: User?
        if let userKey = userKey {
            author = User.objectForKey(objectKey: userKey, in: context)
        } else {
            author = nil
        }

        let postsVC = PostsPageViewController(thread: thread, author: author)
        postsVC.restorationIdentifier = identifierComponents.last
        return postsVC
    }
}

private struct Keys {
    static let threadKey = "ThreadKey"
    static let page = "AwfulCurrentPage"
    static let authorUserKey = "AuthorUserKey"
    static let hiddenPosts = "AwfulHiddenPosts"
    static let replyViewController = "AwfulReplyViewController"
    static let messageViewController = "AwfulMessageViewController"
    static let advertisementHTML = "AwfulAdvertisementHTML"
    static let scrolledFractionOfContent = "AwfulScrolledFractionOfContentSize"
    static let replyWorkspace = "Reply workspace"
}

extension PostsPageViewController {
    override var keyCommands: [UIKeyCommand]? {
        var keyCommands: [UIKeyCommand] = [
            UIKeyCommand(action: #selector(scrollUp), input: UIKeyCommand.inputUpArrow, discoverabilityTitle: "Up"),
            UIKeyCommand(action: #selector(scrollDown), input: UIKeyCommand.inputDownArrow, discoverabilityTitle: "Down"),
            UIKeyCommand(action: #selector(pageUp), input: " ", modifierFlags: .shift, discoverabilityTitle: "Page Up"),
            UIKeyCommand(action: #selector(pageDown), input: " ", discoverabilityTitle: "Page Down"),
            UIKeyCommand(action: #selector(scrollToTop), input: UIKeyCommand.inputUpArrow, modifierFlags: .command, discoverabilityTitle: "Scroll to Top"),
            UIKeyCommand(action: #selector(scrollToBottom(_:)), input: UIKeyCommand.inputDownArrow, modifierFlags: .command, discoverabilityTitle: "Scroll to Bottom"),
        ]

        if case .specific(let pageNumber)? = page, pageNumber > 1 {
            keyCommands.append(UIKeyCommand(action: #selector(loadPreviousPage), input: "[", modifierFlags: .command, discoverabilityTitle: "Previous Page"))
        }

        if case .specific(let pageNumber)? = page, pageNumber < numberOfPages {
            keyCommands.append(UIKeyCommand(action: #selector(loadNextPage), input: "]", modifierFlags: .command, discoverabilityTitle: "Next Page"))
        }

        keyCommands.append(UIKeyCommand(action: #selector(newReply), input: "N", modifierFlags: .command, discoverabilityTitle: "New Reply"))

        return keyCommands
    }
}
