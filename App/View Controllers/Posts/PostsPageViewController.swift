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
import SwiftUI
import UIKit
import WebKit
import AwfulExtensions
import Stencil

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageViewController")

extension Notification.Name {
    static let threadBookmarkDidChange = Notification.Name("threadBookmarkDidChange")
}

/// Shows a list of posts in a thread.
final class PostsPageViewController: ViewController {
    public var coordinator: (any MainCoordinator)?
    var selectedPost: Post? = nil
    var selectedUser: User? = nil
    var selectedFrame: CGRect? = nil
    private var advertisementHTML: String?
    let thread: AwfulThread
    private let author: User?
    private var cancellables: Set<AnyCancellable> = []
    let pageInfoPublisher = PassthroughSubject<(page: ThreadPage?, numberOfPages: Int), Never>()
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
    var jumpToPostIDAfterLoading: String?
    private var messageViewController: MessageComposeViewController?
    private var networkOperation: Task<(posts: [Post], firstUnreadPost: Int?, advertisementHTML: String, pageCount: Int), Error>?
    private var observers: [NSKeyValueObservation] = []
    private lazy var oEmbedFetcher: OEmbedFetcher = .init()
    public private(set) var page: ThreadPage?
    private var pageModel: (posts: [Post], firstUnreadPost: Int?, advertisementHTML: String, pageCount: Int)?
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    private var replyWorkspace: ReplyWorkspace?
    private var restoringState = false
    private var scrollToFractionAfterLoading: CGFloat?
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    private var webViewDidLoadOnce = false
    @FoilDefaultStorage(Settings.enableCustomTitlePostLayout) private var enableCustomTitlePostLayout

    /// Whether to use the SwiftUI toolbar. This should be true for SwiftUI-driven navigation and false for UIKit-driven navigation.
    var useSwiftUIToolbar: Bool = false
    
    /// Hosting controller for the SwiftUI toolbar when useSwiftUIToolbar is true
    private var swiftUIToolbarController: UIHostingController<AnyView>?
    
    /// Hosting controller for the SwiftUI top bar when useSwiftUIToolbar is true
    private var swiftUITopBarController: UIHostingController<AnyView>?
    
    /// Tracks whether the SwiftUI top bar should be visible
    private var isTopBarVisible: Bool = true
    
    /// Tracks the previous scroll offset for determining scroll direction (public for SwiftUI integration)
    public var previousScrollOffset: CGFloat = 0
    
    /// Signifies that the view controller has loaded its content at least once
    public var hasFinishedInitialLoad: Bool = false

    private var firstUnreadPost: Int?
    private var currentPageItem = UIBarButtonItem()
    
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))

    func threadActionsMenu() -> UIMenu {
        return UIMenu(title: self.thread.title ?? "", image: nil, identifier: nil, options: .displayInline, children: [
            // Bookmark
            UIAction(
                title: self.thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread",
                image: UIImage(systemName: self.thread.bookmarked ? "bookmark.slash" : "bookmark"),
                identifier: .init("bookmark"),
                attributes: self.thread.bookmarked ? .destructive : [],
                handler: { [unowned self] action in bookmark(action) }
            ),
            // Copy link
            UIAction(
                title: "Copy link",
                image: UIImage(systemName: "link"),
                identifier: .init("copyLink"),
                handler: { [unowned self] action in copyLink(action) }
            ),
            // Vote
            /*
            UIAction(
                title: "Vote",
                image: UIImage(named: "vote")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("vote"),
                handler: { [unowned self] action in vote(action) }
            ),
            */
            // Your posts
            UIAction(
                title: "Your posts",
                image: UIImage(systemName: "person.crop.rectangle"),
                identifier: .init("yourPosts"),
                handler: { [unowned self] action in yourPosts(action) }
            ),
        ])
    }

    private var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }

    public lazy var postsView: PostsPageView = {
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
        
        postsView.topBar.goToParentForum = { [weak self] in
            guard let self = self, let forum = self.thread.forum else { return }
            
            // On iPhone, we need to navigate differently than iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use coordinator to navigate to forum in sidebar
                if let coordinator = self.coordinator {
                    coordinator.navigateToForum(forum)
                } else {
                    AppDelegate.instance.open(route: .forum(id: forum.forumID))
                }
            } else {
                // iPhone: Navigate to threads list using traditional push navigation
                let threadsVC = ThreadsTableViewController(forum: forum)
                threadsVC.coordinator = self.coordinator
                threadsVC.restorationIdentifier = "Threads"
                self.navigationController?.pushViewController(threadsVC, animated: true)
            }
        }
        
        // Set up scroll callback for SwiftUI top bar visibility
        postsView.didScroll = { [weak self] scrollView in
            // This is now handled by PostsViewWrapper
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

        hidesBottomBarWhenPushed = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        networkOperation?.cancel()
    }

    var posts: [Post] = []

    public var numberOfPages: Int {
        if let author = self.author {
            return Int(self.thread.filteredNumberOfPagesForAuthor(author))
        } else {
            return Int(self.thread.numberOfPages)
        }
    }

    override var theme: Theme {
        guard let forum = self.thread.forum, !forum.forumID.isEmpty else {
            return Theme.defaultTheme()
        }
        return Theme.currentTheme(for: ForumID(forum.forumID))
    }

    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
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
        // logger.info("🔵 Loading page: \(newPage) for thread: \(thread.title ?? "Unknown")")
        
        if let networkOperation = networkOperation {
            // Don't interrupt a refresh in progress.
            if case .specific = newPage, networkOperation.isCancelled {
                return
            }
            networkOperation.cancel()
        }

        page = newPage
        posts = []
        hiddenPosts = 0
        jumpToPostIDAfterLoading = nil
        scrollToFractionAfterLoading = nil

        updateUserInterface()

        if !updatingCache {
            logger.info("🔵 Rendering posts without updating cache")
            renderPosts()
            return
        }

        if
            updateLastReadPost,
            case .specific(let pageNumber) = newPage
        {
            // Assume we've read the whole page. The actual number of posts is only used when loading the last page. A nice big number is fine otherwise.
            let lastReadPostIndex = (pageNumber == thread.numberOfPages) ? Int32.max : Int32(pageNumber * 40)
            if thread.seenPosts < lastReadPostIndex {
                thread.seenPosts = lastReadPostIndex
            }
            if thread.bookmarked {
                thread.anyUnreadPosts = false
            }

            let context = self.thread.managedObjectContext!
            do {
                try context.save()
            } catch {
                logger.error("Failed to save thread context: \(error)")
            }

            NotificationCenter.default.post(name: .threadBookmarkDidChange, object: self.thread)
        }
        
        if case .specific(let pageNumber) = newPage, pageNumber > 1, pageNumber == numberOfPages {
            firstUnreadPost = nil // So we jump to whatever the server tells us.
        } else {
            firstUnreadPost = 0 // Don't jump anywhere.
        }

        logger.info("🔵 Starting network operation to fetch posts")
        networkOperation = Task {
            let (posts, firstUnreadPost, advertisementHTML, pageCount) = try await ForumsClient.shared.listPosts(
                in: self.thread,
                writtenBy: self.author,
                page: newPage,
                updateLastReadPost: updateLastReadPost)
            
            self.pageModel = (posts: posts, firstUnreadPost: firstUnreadPost, advertisementHTML: advertisementHTML, pageCount: pageCount)

            // Back out if we've been cancelled.
            try Task.checkCancellation()
            
            return (posts, firstUnreadPost, advertisementHTML, pageCount)
        }

        
        Task {
            do {
                logger.info("🔵 Waiting for network operation to complete")
                let (newPosts, firstUnread, adHTML, pageCount) = try await networkOperation!.value
                logger.info("🟢 Network operation completed with \(newPosts.count) posts")
                
                // All UI updates must occur on the main actor.
                await MainActor.run {
                    self.advertisementHTML = adHTML

                    // Update the page to reflect the actual page loaded
                    if let firstPost = newPosts.first {
                        let actualPage = firstPost.page
                        self.page = .specific(actualPage)
                    }

                    let context = self.thread.managedObjectContext!

                    // The new posts might have updated info for the logged-in user.
                    if let userID = self.loggedInUserID {
                        let user = User.objectForKey(objectKey: UserKey(userID: userID, username: nil), in: context)
                        user.customTitleHTML = newPosts.first(where: { $0.author?.userID == userID })?.author?.customTitleHTML
                    }

                    // Track any new authors (placeholder implementation).
                    let allAuthors = Set(newPosts.compactMap { $0.author })
                    let knownAuthorIDs = Set(allAuthors.map { $0.userID })
                    _ = User.tombstones(for: knownAuthorIDs, in: context)

                    // Update local state.
                    self.posts = newPosts
                    self.firstUnreadPost = firstUnread
                    
                    // Update thread page count if needed
                    if pageCount != Int(self.thread.numberOfPages) {
                        self.thread.numberOfPages = Int32(pageCount)
                    }

                    do {
                        try context.save()
                    } catch {
                        logger.error("Failed to save context after loading posts: \(error)")
                    }

                    logger.info("🟢 Posts loaded successfully, updating UI")
                    self.updateUserInterface()

                    self.renderPosts()
                }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled {
                    logger.info("🔵 Network operation was cancelled")
                    return 
                }
                
                logger.error("🔴 Failed to load posts: \(error)")
                let alert = UIAlertController(title: "Could Not Load Page", error: error)
                if
                    let page = self.page,
                    case .specific(1) = page
                {
                    alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                        self.loadPage(page, updatingCache: true, updatingLastReadPost: false)
                    })
                }
                present(alert, animated: true)
            }
            
            networkOperation = nil
        }
    }

    private func loadNextPageOrRefresh() {
        if let page = page, case .specific(let pageNumber) = page, pageNumber < numberOfPages {
            loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: false)
        } else {
            loadPage(.specific(1), updatingCache: true, updatingLastReadPost: false)
        }
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Only set up title view for legacy UIKit navigation
        if !useSwiftUIToolbar {
            setupSwiftUITitleView()
        }

        view.addSubview(postsView)
        postsView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            postsView.topAnchor.constraint(equalTo: view.topAnchor),
            postsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            postsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            postsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if navigationController?.viewControllers.first === self, let presentingViewController = presentingViewController {
            if presentingViewController.isBeingPresented {
                navigationItem.leftBarButtonItem = doneButton
            }
        }
        
        themeDidChange()
        
        checkPasteboardForAwfulURL()
        
        updateHandoffUserActivity()
        
        Task {
            loadPage(page ?? .first, updatingCache: true, updatingLastReadPost: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // HACK: On the iPad, when a view controller in the primary navigation controller is fullscreen, then we show another view controller, the primary navigation controller's navigation bar is not visible but its space is taken up. This appears to be an iOS bug. Forcing the navigation bar to be visible seems to fix it.
        if let nav = navigationController, nav.isNavigationBarHidden {
            nav.setNavigationBarHidden(false, animated: animated)
        }

        // When using SwiftUI toolbar, ensure it's up to date
        if useSwiftUIToolbar {
            updateSwiftUIToolbar()
        }

        if let offered = lastOfferedPasteboardURLString, let url = URL(string: offered) {
            if let route = try? AwfulRoute(url) {
                switch route {
                case .threadPage, .threadPageSingleUser:
                    break
                default:
                    lastOfferedPasteboardURLString = nil
                }
            } else {
                lastOfferedPasteboardURLString = nil
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        restoringState = false
        
        if handoffEnabled {
            beginHandoff()
        }

        // This seems to fix an issue where the scrollbar indicators are dark on a dark background when a webview is transparent.
        postsView.renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // If the view controller is being popped from the navigation stack,
        // we need to manually update the coordinator's path to reflect the change.
        if isMovingFromParent {
            if let coordinator = coordinator as? MainCoordinatorImpl {
                coordinator.isTabBarHidden = false
            }
        }
        
        if handoffEnabled {
            userActivity?.invalidate()
        }
        
        if let compose = messageViewController, !compose.isBeingPresented {
            compose.cancel()
            messageViewController = nil
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if useSwiftUIToolbar {
            // Adjust the bottom inset of the posts view to make room for the SwiftUI toolbar
            if let toolbarView = swiftUIToolbarController?.view {
                postsView.renderView.scrollView.contentInset.bottom = view.bounds.height - toolbarView.frame.minY
            }
        }
    }
    
    // MARK: - Legacy Toolbar Setup (for UIKit-driven navigation)
    
    private func setupLegacyToolbar() {
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showPostSettings))
        settingsButton.accessibilityLabel = "Settings"
        
        let backButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(goToPreviousPage))
        backButton.accessibilityLabel = "Previous page"
        
        let forwardButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right"), style: .plain, target: self, action: #selector(goToNextPage))
        forwardButton.accessibilityLabel = "Next page"
        
        currentPageItem = UIBarButtonItem(title: "", style: .plain, target: self, action: #selector(showPagePicker))
        currentPageItem.accessibilityLabel = "Open page picker"
        
        let actionsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: threadActionsMenu())
        actionsButton.accessibilityLabel = "Menu"

        toolbarItems = [
            settingsButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            backButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            currentPageItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            forwardButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            actionsButton,
        ]
    }

    // MARK: - SwiftUI Toolbar/Top Bar Setup
    
    private func setupSwiftUIToolbar() {
        // This is now handled by the SwiftUI wrapper view.
    }
    
    private func updateSwiftUIToolbar() {
        // When using SwiftUI toolbar, we need to notify the SwiftUI view to update
        // This is handled by the PostsViewWrapper's updatePageInfo timer
    }
    
    private func updateSwiftUITopBar() {
        // When using SwiftUI top bar, we need to notify the SwiftUI view to update
        // This is handled by the PostsViewWrapper's updatePageInfo timer
    }
    
    func showThreadActionsMenu() {
        let menu = threadActionsMenu()
        let alert = UIAlertController(title: self.thread.title, message: nil, preferredStyle: .actionSheet)
        
        menu.children.forEach { action in
            if let uiAction = action as? UIAction {
                let alertAction = UIAlertAction(title: uiAction.title, style: .default) { _ in
                    // Recreating the action logic here since handler is not accessible.
                    switch uiAction.identifier.rawValue {
                    case "bookmark": self.bookmark(uiAction)
                    case "copyLink": self.copyLink(uiAction)
                    case "vote": self.vote(uiAction)
                    case "yourPosts": self.yourPosts(uiAction)
                    default: break
                    }
                }
                if uiAction.attributes == .destructive {
                    alertAction.setValue(UIColor.red, forKey: "titleTextColor")
                }
                alert.addAction(alertAction)
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(alert, animated: true)
    }

    private func updateTopBarVisibility(for scrollView: UIScrollView) {
        guard hasFinishedInitialLoad else { return }
        
        let currentOffset = scrollView.contentOffset.y
        let scrollDiff = currentOffset - previousScrollOffset
        
        // Don't do anything if we're at the top or bottom
        guard currentOffset > 0, currentOffset < (scrollView.contentSize.height - scrollView.frame.size.height) else {
            previousScrollOffset = currentOffset
            return
        }
        
        // Hide on scroll down, show on scroll up
        if scrollDiff > 5, isTopBarVisible {
            isTopBarVisible = false
            updateSwiftUITopBar()
        } else if scrollDiff < -5, !isTopBarVisible {
            isTopBarVisible = true
            updateSwiftUITopBar()
        }
        
        previousScrollOffset = currentOffset
    }
    
    public var publicPostsView: PostsPageView {
        return postsView
    }
    
    /// The author user for filtering posts (used by SwiftUI views)
    var authorUser: User? {
        return author
    }

    private func renderPosts() {
        if posts.isEmpty {
            logger.info("🔴 Cannot render posts - posts array is empty")
            return
        }

        logger.info("🔵 Rendering \(self.posts.count) posts")

        let context = RenderContext(
            advertisementHTML: advertisementHTML,
            author: self.author,
            firstUnreadPost: firstUnreadPost,
            fontScale: Int(fontScale),
            hiddenPosts: hiddenPosts,
            isBookmarked: self.thread.bookmarked,
            isLoggedIn: loggedInUserID != nil,
            posts: posts,
            showAvatars: showAvatars,
            showImages: showImages,
            stylesheet: theme[string: "postsViewCSS"] ?? "",
            theme: self.theme,
            username: loggedInUsername,
            enableCustomTitlePostLayout: enableCustomTitlePostLayout,
            enableFrogAndGhost: self.frogAndGhostEnabled
        )
        
        var contextDict = context.makeDictionary()
        contextDict["threadID"] = self.thread.threadID
        contextDict["forumID"] = self.thread.forum?.forumID ?? ""
        logger.info("🔵 Template context prepared with \(contextDict.keys.count) keys")
        let html: String
        do {
            html = try StencilEnvironment.shared.renderTemplate(.postsView, context: contextDict)
            logger.info("🔵 Template rendered, HTML length: \(html.count) characters")
        } catch {
            logger.error("🔴 Template rendering failed: \(error)")
            let alert = UIAlertController(title: "Could not render page", error: error)
            present(alert, animated: true)
            return
        }

        logger.info("🔵 Rendering HTML in web view with base URL: \(ForumsClient.shared.baseURL?.absoluteString ?? "nil")")
        postsView.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
        postsView.renderView.loadLottiePlayer()
        
        // Hide postsView top bar if we're using the SwiftUI version
        postsView.topBarContainer.isHidden = true
        hasFinishedInitialLoad = true
        logger.info("🟢 Posts rendering completed")
    }

    @objc private func didTapDone() {
        dismiss(animated: true)
    }
    
    // MARK: - Actions
    
    @objc public func goToPreviousPage() {
        logger.info("🔵 goToPreviousPage called")
        if let page = page, case .specific(let pageNumber) = page, pageNumber > 1 {
            logger.info("🔵 Going to page \(pageNumber - 1)")
            loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: false)
        } else {
            logger.info("🔴 Cannot go to previous page - already on first page or invalid page state")
        }
    }
    
    @objc public func goToNextPage() {
        logger.info("🔵 goToNextPage called")
        if let page = page, case .specific(let pageNumber) = page, pageNumber < numberOfPages {
            logger.info("🔵 Going to page \(pageNumber + 1)")
            loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: false)
        } else {
            logger.info("🔴 Cannot go to next page - already on last page or invalid page state")
        }
    }
    
    @objc func showPagePicker() {
        logger.info("🔵 showPagePicker called")
        guard let page = page, case .specific(let currentPage) = page else { 
            logger.info("🔴 Cannot show page picker - no valid page state")
            return 
        }
        
        logger.info("🔵 Showing page picker for page \(currentPage) of \(self.numberOfPages)")
        if useSwiftUIToolbar {
            let picker = PostsPagePicker(
                thread: self.thread,
                numberOfPages: numberOfPages,
                currentPage: currentPage,
                onPageSelected: { [weak self] newPage in
                    self?.loadPage(newPage, updatingCache: true, updatingLastReadPost: false)
                    self?.dismiss(animated: true)
                },
                onGoToLastPost: { [weak self] in
                    self?.loadPage(.last, updatingCache: true, updatingLastReadPost: true)
                    self?.dismiss(animated: true)
                }
            )
            let hostingController = UIHostingController(rootView: picker)
            hostingController.modalPresentationStyle = UIModalPresentationStyle.popover
            if let popover = hostingController.popoverPresentationController {
                popover.barButtonItem = currentPageItem
                popover.permittedArrowDirections = UIPopoverArrowDirection.any
            }
            present(hostingController, animated: true)
        } else {
            let picker = PagePickerViewController.make(page: page, numberOfPages: numberOfPages) { [weak self] page in
                self?.loadPage(page, updatingCache: true, updatingLastReadPost: false)
            }
            present(picker, animated: true)
        }
    }
    
    @objc func showPostSettings() {
        let settingsView = PostsPageSettingsView()
        let hostingController = UIHostingController(rootView: settingsView.environment(\.theme, theme))
        hostingController.modalPresentationStyle = UIModalPresentationStyle.popover
        if let popover = hostingController.popoverPresentationController {
            if useSwiftUIToolbar {
                // This is a bit of a guess. In the old code, it seemed to be anchored to a nav bar button,
                // but the new SwiftUI toolbar is at the bottom. We'll present it without an anchor for now.
                // A better solution might involve passing the anchor view from the toolbar.
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = UIPopoverArrowDirection()
            } else {
                popover.barButtonItem = toolbarItems?.first
                popover.permittedArrowDirections = UIPopoverArrowDirection.any
            }
        }
        present(hostingController, animated: true)
    }
    
    @objc func contactSupport() {
        // Present a blank message compose view for support
        // TODO: This is broken. Who's the recipient?
        // let composeVC = MessageComposeViewController()
        // composeVC.restorationIdentifier = "Support Message"
        // composeVC.delegate = self
        // present(composeVC.enclosingNavigationController, animated: true)
    }
    
    func reply(to post: Post? = nil, quoting: Bool = false) {
        let workspace: ReplyWorkspace
        if let post = post {
            workspace = .init(thread: self.thread)
            if quoting {
                Task {
                    if let bbcode = try? await ForumsClient.shared.quoteBBcodeContents(of: post) {
                        workspace.draft.text = NSAttributedString(string: bbcode)
                        presentReplyWorkspace(workspace)
                    }
                }
                return
            }
        } else {
            workspace = .init(thread: self.thread)
        }
        presentReplyWorkspace(workspace)
    }

    private func presentReplyWorkspace(_ workspace: ReplyWorkspace) {
        let vc = workspace.viewController
        present(vc, animated: true)
    }

    private func showPostActions(for post: Post, from rect: CGRect) {
        var actions: [UIAction] = []

        actions.append(UIAction(title: "Reply", handler: { _ in self.replyToPost(post) }))
        actions.append(UIAction(title: "Quote", handler: { _ in self.quotePost(post) }))

        if post.editable {
            actions.append(UIAction(title: "Edit", handler: { _ in self.editPost(post) }))
        }

        actions.append(UIAction(title: "Mark as Read Up To Here", handler: { _ in self.markAsReadUpTo(post) }))
        actions.append(UIAction(title: "Copy Post URL", handler: { _ in self.copyPostURL(post) }))

        let menu = UIMenu(title: "", children: actions)
        hiddenMenuButton.show(menu: menu, from: rect)
    }

    private func showUserActions(for post: Post, from rect: CGRect) {
        guard let author = post.author else { return }

        var actions: [UIAction] = []

        if let user = post.author {
            actions.append(UIAction(title: "Rap Sheet", handler: { _ in self.showRapSheet(for: user) }))
            actions.append(UIAction(title: "Profile", handler: { _ in self.showProfile(for: user) }))
        }

        if canSendPrivateMessages, post.author?.canReceivePrivateMessages == true, post.author?.userID != loggedInUserID {
            actions.append(UIAction(title: "Send Private Message", handler: { _ in self.sendPrivateMessageToAuthor(of: post) }))
        }

        actions.append(UIAction(title: "User's Posts in This Thread", handler: { _ in self.singleUsersPosts(for: post) }))

        let menu = UIMenu(title: author.username ?? "", children: actions)
        hiddenMenuButton.show(menu: menu, from: rect)
    }

    private func showQuote(for post: Post) {
        Task {
            do {
                let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: post)
                let workspace = ReplyWorkspace(thread: self.thread)
                workspace.draft.text = NSAttributedString(string: bbcode)
                presentReplyWorkspace(workspace)
            } catch {
                present(UIAlertController(title: "Could not quote post", error: error), animated: true)
            }
        }
    }
    
    private func replyToPost(_ post: Post) {
        reply(to: post)
    }
    
    private func quotePost(_ post: Post) {
        reply(to: post, quoting: true)
    }

    private func editPost(_ post: Post) {
        Task {
            do {
                let bbcode = try await ForumsClient.shared.findBBcodeContents(of: post)
                let workspace = ReplyWorkspace(post: post, bbcode: bbcode)
                presentReplyWorkspace(workspace)
            } catch {
                present(UIAlertController(title: "Couldn't Edit Post", error: error), animated: true)
            }
        }
    }

    private func markAsReadUpTo(_ post: Post) {
        guard
            let firstUnreadPost = firstUnreadPost,
            let currentPostIndex = posts.firstIndex(of: post),
            currentPostIndex >= firstUnreadPost
        else { return }

        Task {
            do {
                try await ForumsClient.shared.markThreadAsSeenUpTo(post)

                if post.threadIndex >= thread.totalReplies {
                    loadPage(self.page!, updatingCache: true, updatingLastReadPost: true)
                } else {
                    self.firstUnreadPost = currentPostIndex + 1
                    renderPosts()
                }

                NotificationCenter.default.post(name: .threadBookmarkDidChange, object: thread)
            } catch {
                logger.error("Could not mark thread \(self.thread.threadID) as read up to post index \(post.threadIndex): \(error, privacy: .public)")
            }
        }
    }

    private func copyPostURL(_ post: Post) {
        guard
            let page = self.page,
            let baseURL = page.url(for: self.thread, writtenBy: self.author),
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        else { return }

        components.fragment = "post\(post.postID)"
        guard let url = components.url else { return }

        UIPasteboard.general.coercedURL = url
        Task { @MainActor in
            Toast.show(title: "Post URL copied", icon: Toast.Icon.link)
        }
    }
    
    private func showProfile(for user: User) {
        let profile = ProfileViewController(user: user)
        if UIDevice.current.userInterfaceIdiom == .pad {
            present(profile.enclosingNavigationController, animated: true)
        } else {
            navigationController?.pushViewController(profile, animated: true)
        }
    }
    
    private func sendPrivateMessageToAuthor(of post: Post) {
        guard let author = post.author else { return }
        let composeVC = MessageComposeViewController(recipient: author)
        composeVC.restorationIdentifier = "New PM from posts view"
        composeVC.delegate = self
        present(composeVC.enclosingNavigationController, animated: true)
    }
    
    private func showRapSheet(for user: User) {
        let rapSheet = RapSheetViewController(user: user)
        if UIDevice.current.userInterfaceIdiom == .pad {
            present(rapSheet.enclosingNavigationController, animated: true)
        } else {
            navigationController?.pushViewController(rapSheet, animated: true)
        }
    }
    
    private func checkPasteboardForAwfulURL() {
        // Implementation needed
    }

    private func updateHandoffUserActivity() {
        // Implementation needed
    }

    private func makeSwiftUIToolbar() -> some View {
        return PostsToolbarContainer(
            thread: thread,
            author: author,
            page: page,
            numberOfPages: numberOfPages,
            isLoadingViewVisible: postsView.loadingView != nil,
            onSettingsTapped: { [weak self] in
                self?.didTapSettings()
            },
            onBackTapped: { [weak self] in
                self?.goToPreviousPage()
            },
            onForwardTapped: { [weak self] in
                self?.goToNextPage()
            },
            onPageSelected: { [weak self] page in
                self?.goToPage(page)
            },
            onGoToLastPost: { [weak self] in
                self?.goToPage(.last)
            },
            onBookmarkTapped: { [weak self] in
                self?.bookmark(UIAction(title: "", handler: { _ in }))
            },
            onCopyLinkTapped: { [weak self] in
                self?.copyLink(UIAction(title: "", handler: { _ in }))
            },
            onVoteTapped: { [weak self] in
                self?.vote(UIAction(title: "", handler: { _ in }))
            },
            onYourPostsTapped: { [weak self] in
                self?.yourPosts(UIAction(title: "", handler: { _ in }))
            }
        )
    }

    @objc private func didTapReply() {
        reply()
    }

    override func themeDidChange() {
        super.themeDidChange()
        updateUserInterface()
    }

    private func setupSwiftUITitleView() {
        guard let title = thread.title else { return }
        let titleView = PostsPageTitleView(
            title: title,
            onComposeTapped: { [weak self] in
                self?.didTapReply()
            }
        )
        
        let hostingController = UIHostingController(rootView: titleView)
        hostingController.view.backgroundColor = .clear
        navigationItem.titleView = hostingController.view
    }

    /// Go to a specific page (missing method)
    func goToPage(_ newPage: ThreadPage) {
        loadPage(newPage, updatingCache: true, updatingLastReadPost: false)
    }
    
    /// Show settings (missing method)
    @objc func didTapSettings() {
        showPostSettings()
    }

    /// Navigate to the parent forum (called from SwiftUI)
    func goToParentForum() {
        guard let forum = self.thread.forum else { return }
        
        // On iPhone, we need to navigate differently than iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Use coordinator to navigate to forum in sidebar
            if let coordinator = self.coordinator {
                coordinator.navigateToForum(forum)
            } else {
                AppDelegate.instance.open(route: .forum(id: forum.forumID))
            }
        } else {
            // iPhone: Navigate to threads list using traditional push navigation
            let threadsVC = ThreadsTableViewController(forum: forum)
            threadsVC.coordinator = self.coordinator
            threadsVC.restorationIdentifier = "Threads"
            self.navigationController?.pushViewController(threadsVC, animated: true)
        }
    }
    
    private func jumpToPreviousUnread() {
        // Find previous unread post, if any.
    }
}

// MARK: - Post actions
private extension PostsPageViewController {
    
    private func rapSheetForPost(_ post: Post) {
        guard let author = post.author else { return }
        showRapSheet(for: author)
    }
    
    private func profileForPost(_ post: Post) {
        guard let author = post.author else { return }
        showProfile(for: author)
    }
    
    private func sendPrivateMessageToAuthorOfPost(_ post: Post) {
        guard let author = post.author else { return }
        let composeVC = MessageComposeViewController(recipient: author)
        composeVC.restorationIdentifier = "New PM from posts view"
        composeVC.delegate = self
        present(composeVC.enclosingNavigationController, animated: true)
    }
    
    private func singleUsersPosts(for post: Post) {
        guard let author = post.author else { return }
        let postsVC = PostsPageViewController(thread: self.thread, author: author)
        postsVC.coordinator = self.coordinator
        self.navigationController?.pushViewController(postsVC, animated: true)
    }
}

// MARK: - Post header actions
private extension PostsPageViewController {
    @objc func didTapAuthorHeader(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: postsView.renderView)
        let javascript = "Awful.posts.fromPoint(\(location.x), \(location.y))"
        Task {
            do {
                let result = try await postsView.renderView.webView.eval(javascript) as? [String: Any]
                guard
                    let result = result,
                    let postID = result["postID"] as? String,
                    let post = posts.first(where: { $0.postID == postID }),
                    let _ = post.author,
                    let rect = (result["rect"] as? [String: Double]).flatMap(CGRect.init)
                    else { return }
                
                showPostActions(for: post, from: rect)
            } catch {
                logger.error("Could not handle author header tap: \(error, privacy: .public)")
            }
        }
    }
}

extension PostsPageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ compose: ComposeTextViewController, didFinishWithSuccessfulSubmission: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true) {
            self.messageViewController = nil
        }
        if didFinishWithSuccessfulSubmission {
            if let post = compose.value(forKey: "postBeingEdited") as? Post {
                loadPage(.specific(post.page), updatingCache: true, updatingLastReadPost: false)
            } else if let page = page {
                loadPage(page, updatingCache: true, updatingLastReadPost: false)
            } else {
                loadPage(.specific(1), updatingCache: true, updatingLastReadPost: false)
            }
        }
    }
}

// MARK: - RenderViewDelegate

extension PostsPageViewController: RenderViewDelegate {
    
    func didFinishRenderingHTML(in view: RenderView) {
        if embedTweets {
            view.embedTweets()
        }
        
        didFinishLoading(in: view)
    }

    func didReceive(message: RenderViewMessage, in view: RenderView) {
        handle(message: message, in: view)
    }

    func didTapLink(to url: URL, in view: RenderView) {
        // Implement link tap handling as needed
    }

    func renderProcessDidTerminate(in view: RenderView) {
        renderPosts()
    }

    func didFinishLoading(in renderView: RenderView) {
        webViewDidLoadOnce = true

        if let postID = jumpToPostIDAfterLoading {
            jumpToPostIDAfterLoading = nil
            Task {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    scrollToPost(id: postID)
                } catch {
                    logger.error("Failed to scroll to post: \(error)")
                }
            }
        } else if let y = scrollToFractionAfterLoading {
            scrollToFractionAfterLoading = nil
            Task {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    let contentHeight = renderView.scrollView.contentSize.height
                    let viewHeight = renderView.bounds.height
                    renderView.scrollView.contentOffset.y = max(-renderView.scrollView.contentInset.top, (y * contentHeight) - (viewHeight / 2))
                } catch {
                    logger.error("Failed to scroll to fraction: \(error)")
                }
            }
        } else if self.jumpToLastPost, case .specific(let pageNumber) = self.page, pageNumber == self.numberOfPages, self.author == nil {
            self.jumpToLastPost = false
            self.postsView.renderView.scrollView.setContentOffset(CGPoint(x: 0, y: self.postsView.renderView.scrollView.contentSize.height), animated: false)
        } else if let postIndex = self.firstUnreadPost {
            self.firstUnreadPost = nil
            Task {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    scrollToPost(at: postIndex)
                } catch {
                    logger.error("Failed to scroll to post index: \(error)")
                }
            }
        }
        
        hasFinishedInitialLoad = true
    }

    func didTapPostActionButton(_ button: UIButton, in renderView: RenderView) {
        let javascript = "Awful.posts.fromPoint(\(button.center.x), \(button.center.y))"
        Task {
            do {
                let result = try await renderView.webView.eval(javascript) as? [String: Any]
                guard
                    let result = result,
                    let postID = result["postID"] as? String,
                    let post = posts.first(where: { $0.postID == postID })
                    else { return }

                self.postIndex = self.posts.firstIndex(of: post) ?? 0

                let rect = self.view.convert(button.bounds, from: button)
                showPostActions(for: post, from: rect)
            } catch {
                logger.error("Could not handle action button tap: \(error, privacy: .public)")
            }
        }
    }
    
    func handle(message: RenderViewMessage, in renderView: RenderView) {
        switch message {
        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            // After all tweets are loaded, we might need to re-adjust the scroll position.
            didFinishLoading(in: renderView)

        case let message as RenderView.BuiltInMessage.FetchOEmbedFragment:
            Task {
                do {
                    let fragment = await oEmbedFetcher.fetch(url: message.url, id: message.id)
                    let javascript = "Awful.invoke(\'oembed.process\', \(fragment))"
                    try await renderView.webView.eval(javascript)
                } catch {
                    logger.error("oembed fetch for \(message.url, privacy: .public) failed: \(error, privacy: .public)")
                }
            }

        case is FYADFlagRequest:
            flagRequest?.cancel()
            flagRequest = Task {
                let client = ForumsClient.shared
                if let forum = thread.forum {
                    _ = try await client.flagForThread(in: forum)
                }
            }
            Task {
                do {
                    try await flagRequest!.value
                    // Toast.show(title: "Thanks, I guess")
                } catch {
                    present(UIAlertController(title: "Could not flag thread", error: error), animated: true)
                }
            }
            
        case let message as RenderView.BuiltInMessage.DidTapPostActionButton:
            guard message.postIndex < posts.count else { return }
            let post = posts[message.postIndex]
            self.postIndex = message.postIndex
            showPostActions(for: post, from: message.frame)

        case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
            guard message.postIndex < posts.count else { return }
            let post = posts[message.postIndex]
            showUserActions(for: post, from: message.frame)
            
        default:
            logger.error("unhandled message: \(type(of: message))")
        }
    }
}

extension PostsPageViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension PostsPageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard
            let threadID = coder.decodeObject(forKey: Keys.threadID) as? NSManagedObjectID,
            let thread = try? AppDelegate.instance.managedObjectContext.existingObject(with: threadID) as? AwfulThread
            else { return nil }
        
        let authorID = coder.decodeObject(forKey: Keys.authorID) as? NSManagedObjectID
        let author = authorID.flatMap { try? AppDelegate.instance.managedObjectContext.existingObject(with: $0) as? User }
        
        let postsVC = PostsPageViewController(thread: thread, author: author)
        postsVC.restorationIdentifier = identifierComponents.last
        
        let pageNumber = coder.decodeInteger(forKey: Keys.page)
        if pageNumber > 0 {
            postsVC.page = .specific(pageNumber)
        } else if let pageRawValue = coder.decodeObject(forKey: Keys.pageRaw) as? String {
            postsVC.page = ThreadPage(rawValue: pageRawValue)
        }
        
        postsVC.scrollToFractionAfterLoading = coder.decodeObject(forKey: Keys.scrollFraction) as? CGFloat
        
        return postsVC
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(self.thread.objectID, forKey: Keys.threadID)
        coder.encode(self.author?.objectID, forKey: Keys.authorID)
        if let page = page, case .specific(let pageNumber) = page {
            coder.encode(pageNumber, forKey: Keys.page)
        }
        coder.encode(page?.rawValue, forKey: Keys.pageRaw)
        
        let scrollView = postsView.renderView.scrollView
        let scrollFraction = (scrollView.contentOffset.y + scrollView.contentInset.top) / (scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom)
        if scrollFraction.isFinite, scrollFraction > 0 {
            coder.encode(scrollFraction, forKey: Keys.scrollFraction)
        }
        
        if let presented = presentedViewController {
            coder.encode(presented, forKey: Keys.presentedViewController)
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        if let presented = coder.decodeObject(forKey: Keys.presentedViewController) as? UIViewController {
            present(presented, animated: false)
        }
    }
}

extension PostsPageViewController {
    
    func updateUserInterface() {
        updateSwiftUIToolbar()
        updateSwiftUITopBar()
        pageInfoPublisher.send((page: page, numberOfPages: numberOfPages))
      
        postsView.refreshControl?.isHidden = self.author != nil

        // Determine if we should show the loading view
        let shouldShowLoading = posts.isEmpty && networkOperation != nil
        logger.info("🔵 updateUserInterface: posts.count=\(self.posts.count), networkOperation!=nil=\(self.networkOperation != nil), shouldShowLoading=\(shouldShowLoading)")

        postsView.backgroundColor = theme["backgroundColor"]

        if shouldShowLoading {
            postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
        } else {
            postsView.loadingView = nil
        }

        if handoffEnabled {
            beginHandoff()
        }

        if let (posts, firstUnreadPost, advertisementHTML, pageCount) = pageModel {
            let context = RenderContext(
                advertisementHTML: advertisementHTML,
                author: author,
                firstUnreadPost: firstUnreadPost,
                fontScale: Int(fontScale),
                hiddenPosts: hiddenPosts,
                isBookmarked: thread.bookmarked,
                isLoggedIn: loggedInUserID != nil,
                posts: posts,
                showAvatars: showAvatars,
                showImages: showImages,
                stylesheet: theme[string: "postsViewCSS"] ?? "",
                theme: self.theme,
                username: loggedInUsername,
                enableCustomTitlePostLayout: enableCustomTitlePostLayout,
                enableFrogAndGhost: self.frogAndGhostEnabled
            )
            
            // Update thread page count if needed
            if pageCount != Int(self.thread.numberOfPages) {
                self.thread.numberOfPages = Int32(pageCount)
            }
            
            do {
                let html = try StencilEnvironment.shared.renderTemplate(.postsView, context: context.makeDictionary())
                postsView.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
            } catch {
                logger.error("Failed to render posts: \(error)")
                postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
            }
        }
    }
    


    func beginHandoff() {
        let activity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
        activity.title = title
        if let page = page {
            activity.webpageURL = page.url(for: self.thread, writtenBy: self.author)
        }
        userActivity = activity
        userActivity?.becomeCurrent()
    }
    
    func scrollToPost(at index: Int) {
        guard index >= 0 && index < posts.count else { return }
        let postID = posts[index].postID
        postsView.renderView.jumpToPost(identifiedBy: postID)
    }
    
    func scrollToPost(id: String) {
        postsView.renderView.jumpToPost(identifiedBy: id)
    }

    @objc func scrollToBottom() {
        let scrollView = postsView.renderView.scrollView
        let bottomOffset = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.contentInset.bottom))
        scrollView.setContentOffset(bottomOffset, animated: true)
    }
    
    
    // MARK: - SwiftUI Interface Methods
    
    /// Triggers the settings view (called from SwiftUI)
    func triggerSettings() {
        showPostSettings()
    }
    
    /// Triggers bookmark action (called from SwiftUI)
    func triggerBookmark() {
        let action = UIAction(title: "", handler: { _ in })
        bookmark(action)
    }
    
    /// Triggers copy link action (called from SwiftUI)
    func triggerCopyLink() {
        let action = UIAction(title: "", handler: { _ in })
        copyLink(action)
    }
    
    /// Triggers vote action (called from SwiftUI)
    func triggerVote() {
        let action = UIAction(title: "", handler: { _ in })
        vote(action)
    }
    
    /// Triggers your posts action (called from SwiftUI)
    func triggerYourPosts() {
        let action = UIAction(title: "", handler: { _ in })
        yourPosts(action)
    }
    
    /// Goes to the last post (called from SwiftUI)
    func goToLastPost() {
        loadPage(.last, updatingCache: true, updatingLastReadPost: true)
    }
    
    /// Creates a new reply (called from SwiftUI)
    @objc func newReply() {
        reply()
    }
}

extension PostsPageViewController {
    @objc func bookmark(_ action: UIAction) {
        let bookmarked = !thread.bookmarked
        Task {
            do {
                try await ForumsClient.shared.setThread(self.thread, isBookmarked: bookmarked)
                self.thread.bookmarked = bookmarked
                try self.thread.managedObjectContext?.save()
                updateUserInterface()
                Toast.show(title: bookmarked ? "Bookmarked" : "Unbookmarked", icon: bookmarked ? Toast.Icon.bookmark : Toast.Icon.bookmarkSlash)
            } catch {
                present(UIAlertController(title: "Could not set bookmark", message: "Please try again.", preferredStyle: .alert), animated: true)
            }
        }
    }

    @objc func copyLink(_ action: UIAction) {
        guard let page = self.page, let url = page.url(for: self.thread, writtenBy: self.author) else { return }
        UIPasteboard.general.coercedURL = url
        Toast.show(title: "Copied link", icon: Toast.Icon.link)
    }
    
    @objc func vote(_ action: UIAction) {
        // let alert = RatingViewController(thread: self.thread)
    }

    @objc func yourPosts(_ action: UIAction) {
        guard let loggedInUserID = self.loggedInUserID else { return }
        let authorKey = UserKey(userID: loggedInUserID, username: self.loggedInUsername)
        let author = User.objectForKey(objectKey: authorKey, in: self.thread.managedObjectContext!)
        let postsVC = PostsPageViewController(thread: self.thread, author: author)
        postsVC.coordinator = self.coordinator
        self.navigationController?.pushViewController(postsVC, animated: true)
    }
}

private enum Keys {
    static let authorID = "authorID"
    static let page = "page"
    static let pageRaw = "pageRaw"
    static let presentedViewController = "presentedViewController"
    static let scrollFraction = "scrollFraction"
    static let threadID = "threadID"
}

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
            "advertisementHTML": advertisementHTML as Any,
            "externalStylesheet": "", // No external stylesheet needed
            "firstUnreadPost": firstUnreadPost as Any,
            "fontScale": fontScale,
            "hiddenPosts": hiddenPosts,
            "isBookmarked": isBookmarked,
            "isLoggedIn": isLoggedIn,
            "posts": posts.map { PostRenderModel($0, enableCustomTitlePostLayout: enableCustomTitlePostLayout).asDictionary(showAvatars: showAvatars) },
            "script": "", // No JavaScript needed for now
            "showAvatars": showAvatars,
            "showImages": showImages,
            "stylesheet": stylesheet,
            "threadID": "", // Will be filled in by the caller
            "forumID": "", // Will be filled in by the caller
            "tweetTheme": theme[string: "mode"] ?? "light",
            "enableFrogAndGhost": enableFrogAndGhost,
            "endMessage": posts.count > 0, // Show end message if we have posts
            "username": username as Any,
            "enableCustomTitlePostLayout": enableCustomTitlePostLayout
        ]
        if enableFrogAndGhost {
            let url = Bundle.main.url(forResource: "ghost60", withExtension: "json")!
            let data = try! Data(contentsOf: url)
            context["ghostJsonData"] = String(data: data, encoding: .utf8) as Any
        }

        if let author = author {
            context["author"] = UserRenderModel(author, enableCustomTitlePostLayout: enableCustomTitlePostLayout).asDictionary(showAvatars: showAvatars)
        }
        return context
    }

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
            if let rawDate = self.post.value(forKey: "postDateRaw") as? String, !rawDate.isEmpty {
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
                guard let name = role.value(forKey: "name") as? String else { return nil }
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
        
        // For template compatibility, expose properties using dictionary-like access
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
            if let rawDate = self.user.value(forKey: "regdateRaw") as? String, !rawDate.isEmpty {
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
}

private extension Post {
    var postDateRaw: String {
        if let rawDate = self.value(forKey: "postDateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return postDate.map { DateFormatter.postDateFormatter.string(from: $0) } ?? ""
    }
}

private extension User {
    var regdateRaw: String {
        if let rawDate = self.value(forKey: "regdateRaw") as? String, !rawDate.isEmpty {
            return rawDate
        }
        return regdate.map { DateFormatter.regDateFormatter.string(from: $0) } ?? ""
    }
}

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

private extension PostsPageView {
    func scrollToPost(id: String) {
        renderView.jumpToPost(identifiedBy: id)
    }
}

private extension ThreadPage {
    var pageNumber: Int? {
        switch self {
        case .specific(let n): return n
        default: return nil
        }
    }

    var rawValue: String? {
        switch self {
        case .last: return "last"
        case .nextUnread: return "nextunread"
        case .specific(let n): return "specific\(n)"
        }
    }
    
    init?(rawValue: String) {
        if rawValue == "last" {
            self = .last
        } else if rawValue == "nextunread" {
            self = .nextUnread
        } else if rawValue.hasPrefix("specific") {
            let num = String(rawValue.dropFirst("specific".count))
            if let n = Int(num) {
                self = .specific(n)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func url(for thread: AwfulThread, writtenBy author: User?) -> URL? {
        guard var components = URLComponents(url: ForumsClient.shared.baseURL!, resolvingAgainstBaseURL: true) else { return nil }
        components.path = "/showthread.php"
        
        var queryItems: [URLQueryItem] = [.init(name: "threadid", value: thread.threadID)]
        switch self {
        case .last:
            queryItems.append(.init(name: "goto", value: "lastpost"))
        case .nextUnread:
            queryItems.append(.init(name: "goto", value: "newpost"))
        case .specific(let page):
            queryItems.append(.init(name: "pagenumber", value: "\(page)"))
        }
        
        if let author = author {
            queryItems.append(.init(name: "userid", value: author.userID))
        }
        
        components.queryItems = queryItems
        return components.url
    }
}
