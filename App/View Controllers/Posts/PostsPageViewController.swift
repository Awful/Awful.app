//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@preconcurrency import AwfulCore
import AwfulExtensions
import AwfulModelTypes
import AwfulPolls
import AwfulRapsheet
import AwfulSearch
import AwfulSettings
import AwfulTheming
import AwfulTilt
import Combine
@preconcurrency import CoreData
import MobileCoreServices
import MRProgress
import os
import UIKit
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPageViewController")

/// Shows a list of posts in a thread.
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
    @FoilDefaultStorage(Settings.endlessScrollPosts) private var endlessScrollPosts
    /// Non-nil while an endless-scroll append of the next page is in flight.
    private var appendTask: Task<Void, Never>?
    /// True once endless scroll has appended pages, so `posts` spans multiple pages and
    /// `page`/`hiddenPosts` no longer describe a single page's document.
    private var endlessScrollDidAppend = false
    private var flagRequest: Task<Void, Error>?
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    @FoilDefaultStorage(Settings.hidePostMetadataForReader) private var hidePostMetadataForReader
    private var jumpToLastPost = false
    @FoilDefaultStorageOptional(Settings.lastOfferedPasteboardURLString) private var lastOfferedPasteboardURLString
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    @FoilDefaultStorageOptional(Settings.username) private var loggedInUsername
    var postIndex: Int = 0
    @FoilDefaultStorage(Settings.jumpToPostEndOnDoubleTap) private var jumpToPostEndOnDoubleTap
    private var jumpToPostIDAfterLoading: String?
    private var messageViewController: MessageComposeViewController?
    private var cancelNetworkOperation: (() -> Void)?
    private var observers: [NSKeyValueObservation] = []
    private lazy var oEmbedFetcher: OEmbedFetcher = .init()
    private(set) var page: ThreadPage?
    /// The thread's poll, once a page has come back from the Forums saying there is one. We don't
    /// persist it: it's cheap to re-scrape and goes stale the moment anyone votes.
    private var poll: ThreadPoll?
    /// Whether we've already considered offering the poll toast during this visit to the thread.
    /// Set on the first render that has a poll to offer, and never reset, so the on-disk check in
    /// `OfferedPollToastStore` happens once per visit rather than once per render.
    private var hasOfferedPollToast = false
    @FoilDefaultStorage(Settings.pullForNext) private var pullForNext
    private var replyWorkspace: ReplyWorkspace? {
        didSet {
            replyWorkspace?.onInteractiveDismiss = { [weak self] in
                self?.setMinimizedDraftBarVisible(true)
            }
            if replyWorkspace == nil {
                setMinimizedDraftBarVisible(false)
            }
        }
    }
    private var scrollToFractionAfterLoading: CGFloat?
    /// When true, the next `loadPage` network completion skips its usual "save current scroll
    /// offset so we land in the same place after re-render" step. Set by `prepareForRestoration`
    /// so a freshly restored scroll fraction isn't clobbered by the in-flight fetch that the URL
    /// router kicked off before `SceneDelegate` could stage the restored value.
    private var suppressNextScrollFractionPreservation = false

    /// Topmost-visible post, refreshed asynchronously on scroll-stop. Read synchronously
    /// when iOS asks for a state-restoration activity; survives content growth and rotation,
    /// unlike a normalized scroll fraction.
    private var cachedAnchorPostID: String?
    private var cachedAnchorDeltaY: CGFloat?
    private var refreshAnchorTask: Task<Void, Never>?

    /// Keeps the loading view up briefly after render when the first posts contain tweet/Bluesky
    /// embeds, so their layout-shifting reflow happens behind the throbber instead of in the
    /// user's face. Cleared early once tweets settle, or on the next page load.
    private var loadingHoldTask: Task<Void, Never>?
    private static let loadingHoldDuration: TimeInterval = 2
    /// How many of the first visible posts to scan for embeds when deciding whether to hold.
    private static let embedScanPostCount = 10

    /// Anchor staged by `prepareForRestoration`, consumed in `didFinishRenderingHTML`.
    /// Demoted to nil in `loadPage`'s network completion when the saved post isn't on the
    /// loaded page, so the existing first-unread fallback takes over.
    private var anchorPostIDAfterLoading: String?
    private var anchorDeltaAfterLoading: CGFloat?
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    let thread: AwfulThread
    private var webViewDidLoadOnce = false

    func threadActionsMenu() -> UIMenu {
        var children: [UIMenuElement] = [
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
            // Vote (the thread's star rating, not a poll)
            UIAction(
                title: "Vote",
                image: UIImage(named: "vote")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("vote"),
                handler: { [unowned self] in vote(action: $0) }
            ),
        ]

        // The menu is rebuilt on every tap, so this stays in step with whatever the last page load
        // told us. Threads without a poll — nearly all of them — don't get a dead row.
        if poll != nil {
            children.append(UIAction(
                title: "View poll",
                image: UIImage(named: "poll")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("viewPoll"),
                handler: { [unowned self] in viewPoll(action: $0) }
            ))
        }

        children += [
            // Your posts
            UIAction(
                title: "Your posts",
                image: UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("yourPosts"),
                handler: { [unowned self] in yourPosts(action: $0) }
            ),
            // Search thread
            UIAction(
                title: "Search thread",
                image: UIImage(named: "view-in-thread")!.withRenderingMode(.alwaysTemplate),
                identifier: .init("searchThread"),
                handler: { [unowned self] in searchThread(action: $0) }
            ),
        ]

        // A shortcut back to the search results. Usually they're still further down this stack, in
        // which case it just pops to them; otherwise it fetches them again from the stored query ID.
        // Rebuilt with the menu, so it goes away once neither is true.
        let hasResultsBelow = navigationController?.viewControllers
            .contains { $0 is SearchResultsViewController } ?? false
        if LastSearchStore.hasStoredResults || hasResultsBelow {
            children.append(UIAction(
                title: "Search results",
                image: UIImage(systemName: "text.magnifyingglass"),
                identifier: .init("lastSearchResults"),
                handler: { [unowned self] in lastSearchResults(action: $0) }
            ))
        }

        return UIMenu(title: thread.title ?? "", image: nil, identifier: nil, options: .displayInline, children: children)
    }

    private var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }
    private var hiddenPostsAfterLoading: Int?

    private lazy var postsView: PostsPageView = {
        let postsView = PostsPageView()
        postsView.postsPageViewController = self
        postsView.didStartRefreshing = { [weak self] in
            self?.loadNextPageOrRefresh()
        }
        postsView.renderView.delegate = self
        postsView.renderView.registerMessage(FYADFlagRequest.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidTapPostActionButton.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.FetchOEmbedFragment.self)
        postsView.renderView.registerMessage(RenderView.BuiltInMessage.ImageLoadProgress.self)
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

            updateInterfaceStyle()
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        func show(menu: UIMenu, from rect: CGRect) {
            frame = rect
            self.menu = menu

            updateInterfaceStyle()

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

        navigationItem.rightBarButtonItem = composeItem

        hidesBottomBarWhenPushed = true
    }

    deinit {
        cancelNetworkOperation?()
        loadingHoldTask?.cancel()
        appendTask?.cancel()
        quoteFetchTask?.cancel()
    }

    /// Fetches quote BBcode and inserts it into the reply workspace's live text view, so it must be
    /// cancelled whenever the workspace it targets goes away.
    private var quoteFetchTask: Task<Void, Never>?

    /// Mail-style minimized draft: swiping the compose sheet away leaves this banner at the bottom
    /// of the thread; tapping it (or any reply/quote/edit action) brings the sheet back.
    private var minimizedDraftBanner: BannerToastView?

    private var minimizedDraftMessage: String {
        switch replyWorkspace?.status {
        case .editing:
            return "Editing: \(thread.title ?? "")"
        case .replying, nil:
            return replyWorkspace?.draft.title ?? ""
        }
    }

    private func setMinimizedDraftBarVisible(_ visible: Bool) {
        guard visible else {
            minimizedDraftBanner?.dismiss()
            minimizedDraftBanner = nil
            return
        }
        guard isViewLoaded, replyWorkspace != nil else { return }

        minimizedDraftBanner?.dismiss(animated: false)
        minimizedDraftBanner = BannerToastView.show(
            in: view,
            theme: theme,
            message: minimizedDraftMessage,
            duration: nil,
            bottomInset: pollToastBottomInset,
            onAction: { [weak self] in self?.showReplyWorkspace() }
        )
    }

    /// Presents the reply workspace's compose sheet, dismissing the minimized-draft banner. Safe to
    /// call while the sheet is already on screen.
    private func showReplyWorkspace() {
        guard let workspace = replyWorkspace else { return }
        setMinimizedDraftBarVisible(false)
        let viewController = workspace.viewController
        guard viewController.presentingViewController == nil else { return }
        present(viewController, animated: true)
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
            // While a push/pop animates, only touch the text: `navigationItem.titleLabel` can
            // re-host the label, and swapping the title view mid-transition makes UIKit rebuild
            // the incoming item's bar content under the animating back button.
            if transitionCoordinator != nil, let label = navigationItem.titleView as? UILabel {
                label.text = title
            } else {
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
        cancelNetworkOperation?()
        cancelNetworkOperation = nil
        // A fresh page load collapses any endless-scroll accumulation.
        appendTask?.cancel()
        appendTask = nil

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
        // Anchor is page-scoped; cleared for the same reason as scrollToFractionAfterLoading.
        anchorPostIDAfterLoading = nil
        anchorDeltaAfterLoading = nil
        // Cancel any embed loading-view hold from a previous load so it can't dismiss the
        // fresh loading view we're about to show.
        loadingHoldTask?.cancel()
        loadingHoldTask = nil

        // SA: When filtering the thread by a single user, the "goto=lastpost" redirect ignores the user filter, so we'll do our best to guess.
        var newPage = newPage
        if let author = author, case .last? = page {
            newPage = .specific(Int(thread.filteredNumberOfPagesForAuthor(author)))
        }

        // Reloading `page` after endless-scroll appends is not a same-document reload: the
        // completion replaces the accumulated `posts` with one page's worth, so skipping the
        // reset below would leave `hiddenPosts` pointing past the end of `posts`.
        let reloadingSamePage = page == newPage && !endlessScrollDidAppend
        page = newPage
        endlessScrollDidAppend = false

        if posts.isEmpty || !reloadingSamePage {
            postsView.endRefreshing()

            updateUserInterface()

            hiddenPosts = 0

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

        struct FetchResult: @unchecked Sendable {
            let posts: [Post]
            let firstUnreadPost: Int?
            let advertisementHTML: String
            let poll: ThreadPoll?
        }
        let fetch = Task {
            let result = try await ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: newPage, updateLastReadPost: updateLastReadPost)
            return FetchResult(posts: result.posts, firstUnreadPost: result.firstUnreadPost, advertisementHTML: result.advertisementHTML, poll: result.poll)
        }
        cancelNetworkOperation = { fetch.cancel() }
        Task { [weak self] in
            do {
                let fetchResult = try await fetch.value
                let (posts, firstUnreadPost) = (fetchResult.posts, fetchResult.firstUnreadPost)
                guard let self else { return }

                // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
                guard self.page == newPage else { return }

                // Set before `renderPosts()` below so the render's completion callback can offer
                // the toast. (Also updated after a vote, in `presentPollViewer`.)
                //
                // Sticky on purpose: we don't know for sure that the forums put the poll block on
                // every page of a thread, and a later page coming back without one shouldn't yank
                // "View poll" back out of the menu.
                if let poll = fetchResult.poll {
                    self.poll = poll
                }

                if self.theme != initialTheme {
                    self.themeDidChange()
                }

                if !posts.isEmpty {
                    self.posts = posts

                    self.page = .specific(self.pageNumber(of: posts[0]))
                }

                switch newPage {
                case .last where self.posts.isEmpty,
                     .nextUnread where self.posts.isEmpty:
                    if LiquidGlass.isEnabled {
                        self.pageNumberView.currentPage = 0
                        self.pageNumberView.totalPages = self.numberOfPages > 0 ? self.numberOfPages : 0
                    } else {
                        let pageCount = self.numberOfPages > 0 ? "\(self.numberOfPages)" : "?"
                        self.currentPageItem.title = "Page ? of \(pageCount)"
                    }

                case .last, .nextUnread, .specific:
                    break
                }

                self.configureUserActivityIfPossible()

                // If the staged anchor isn't on the loaded page (rolled over, filter
                // excludes, deleted), drop everything so the first-unread fallback below
                // takes over.
                let stagedAnchorIndex = self.anchorPostIDAfterLoading.flatMap { anchorID in
                    self.posts.firstIndex(where: { $0.postID == anchorID })
                }
                if self.anchorPostIDAfterLoading != nil, stagedAnchorIndex == nil {
                    self.scrollToFractionAfterLoading = nil
                    self.hiddenPostsAfterLoading = nil
                    self.anchorPostIDAfterLoading = nil
                    self.anchorDeltaAfterLoading = nil
                }

                if let pendingHidden = self.hiddenPostsAfterLoading {
                    // A count that would hide every post, or hide the (by definition visible)
                    // anchor, came from an inconsistent payload — e.g. an older build's snapshot
                    // taken mid-endless-scroll — so show everything rather than an empty document.
                    let anchorWouldBeHidden = stagedAnchorIndex.map { $0 < pendingHidden } ?? false
                    if pendingHidden <= 0 || pendingHidden >= self.posts.count || anchorWouldBeHidden {
                        self.hiddenPosts = 0
                    } else {
                        self.hiddenPosts = pendingHidden
                    }
                    self.hiddenPostsAfterLoading = nil
                } else if self.hiddenPosts == 0, let firstUnreadPost = firstUnreadPost, firstUnreadPost > 0 {
                    let pendingTargetOnPage: Bool
                    if let pendingPostID = self.jumpToPostIDAfterLoading {
                        pendingTargetOnPage = self.posts.contains(where: { $0.postID == pendingPostID })
                    } else {
                        pendingTargetOnPage = false
                    }
                    if !pendingTargetOnPage {
                        self.hiddenPosts = firstUnreadPost - 1
                    }
                }

                if self.suppressNextScrollFractionPreservation {
                    self.suppressNextScrollFractionPreservation = false
                } else if reloadingSamePage || renderedCachedPosts {
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
                    if LiquidGlass.isEnabled {
                        self.pageNumberView.currentPage = 0
                        self.pageNumberView.totalPages = self.numberOfPages > 0 ? self.numberOfPages : 0
                    } else {
                        let pageCount = self.numberOfPages > 0 ? "\(self.numberOfPages)" : "?"
                        self.currentPageItem.title = "Page ? of \(pageCount)"
                    }

                case .last, .nextUnread, .specific:
                    break
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

            postsView.renderView.jumpToPost(identifiedBy: post.postID, topOffset: postsView.topInsetForPostFraming)
        }
    }

    func goToLastPost() {
        loadPage(.last, updatingCache: true, updatingLastReadPost: true)
        jumpToLastPost = true
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    private func renderPosts() {
        webViewDidLoadOnce = false

        var context: [String: Any] = [:]

        context["stylesheet"] = theme[string: "postsViewCSS"] as Any

        if posts.count > hiddenPosts {
            let subset = posts[hiddenPosts...]
            if endlessScrollPosts {
                // Re-emit page dividers so a full re-render (theme change, web process termination) reproduces the accumulated document.
                var previousPage: Int?
                context["posts"] = subset.map { post -> [String: Any] in
                    var postContext = PostRenderModel(post).context
                    let postPage = pageNumber(of: post)
                    if let previousPage, postPage != previousPage {
                        postContext["pageDivider"] = "Page \(postPage) of \(numberOfPages)"
                    }
                    previousPage = postPage
                    return postContext
                }
            } else {
                context["posts"] = subset.map { PostRenderModel($0).context }
            }
        }

        if let ad = advertisementHTML, !ad.isEmpty {
            context["advertisementHTML"] = ad
        }

        if context["posts"] != nil, case .specific(let pageNumber)? = page, pageNumber >= numberOfPages {
            context["endMessage"] = true
        }

        context["enableFrogAndGhost"] = frogAndGhostEnabled

        context["ghostJsonData"] = try? String(contentsOf: URL(string: "ghost60.json", relativeTo: Bundle.main.resourceURL)!, encoding: .utf8)

        if let loggedInUsername, !loggedInUsername.isEmpty {
            context["loggedInUsername"] = loggedInUsername
        }

        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet

        if !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID
        }

        if let forum = thread.forum, !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }

        context["tweetTheme"] = theme[string: "postsTweetTheme"] ?? "light"

        prefetchAttachments(inPostsContext: context["posts"] as? [[String: Any]] ?? [])

        Task.detached(priority: .userInitiated) { [context] in
            let html: String
            do {
                html = try StencilEnvironment.shared.renderTemplate(.postsView, context: context)
            } catch {
                logger.error("could not render posts view HTML: \(error)")
                html = ""
            }

            await self.postsView.renderView.eraseDocument()
            await self.postsView.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
        }
    }

    /// Starts fetching the page's first few attachments concurrently with the template render, so their bytes are cached — or at least in flight — by the time WebKit asks `AttachmentSchemeHandler` for them during page load.
    private func prefetchAttachments(inPostsContext posts: [[String: Any]]) {
        guard !posts.isEmpty else { return }
        Task.detached(priority: .utility) {
            let maxPrefetches = 10
            let regex = try! NSRegularExpression(pattern: "data-awful-attachment-id=\"(\\d+)\"")
            var attachmentIDs: [String] = []
            var seen: Set<String> = []
            for post in posts {
                guard let html = post["htmlContents"] as? String else { continue }
                regex.enumerateMatches(in: html, range: NSRange(html.startIndex..., in: html)) { match, _, _ in
                    if let match, let idRange = Range(match.range(at: 1), in: html) {
                        let id = String(html[idRange])
                        if seen.insert(id).inserted {
                            attachmentIDs.append(id)
                        }
                    }
                }
                if attachmentIDs.count >= maxPrefetches { break }
            }
            for id in attachmentIDs.prefix(maxPrefetches) {
                Task {
                    _ = try? await AttachmentSchemeHandler.attachment(id: id)
                }
            }
        }
    }

    /// Posting is impossible while browsing the archives, so threads behave as if closed.
    private var isArchivesMode: Bool {
        ForumsClient.shared.currentArchivesTimeframe != nil
    }

    private lazy var composeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(compose))
        item.accessibilityLabel = NSLocalizedString("compose.accessibility-label", comment: "")
        // Only set explicit tint color when the system isn't drawing glass buttons
        if !LiquidGlass.isEnabled {
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
            showReplyWorkspace()
        }

        switch replyWorkspace?.status {
        case .editing:
            presentDraftMenu(
                from: .barButtonItem(sender),
                options: .init(
                    continueEditing: presentReply,
                    deleteDraft: { [weak self] in
                        self?.replyWorkspace?.forgetDraft()
                        makeNewReplyWorkspace()
                        presentReply()
                    })
            )

        case .replying where isLongPress:
            presentDraftMenu(
                from: .barButtonItem(sender),
                options: .init(
                    continueEditing: presentReply,
                    deleteDraft: { [weak self] in
                        self?.replyWorkspace?.forgetDraft()
                        makeNewReplyWorkspace()
                    })
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
        showReplyWorkspace()
    }

    private var replyCompletionBlock: (_ result: ReplyWorkspace.CompletionResult) -> Void {
        return { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .forgetAboutIt:
                self.quoteFetchTask?.cancel()
                self.replyWorkspace = nil

            case .posted:
                self.quoteFetchTask?.cancel()
                self.replyWorkspace = nil
                self.loadPage(.nextUnread, updatingCache: true, updatingLastReadPost: true)

            case .saveDraft:
                self.setMinimizedDraftBarVisible(true)
            }

            // The workspace can complete without its sheet on screen (e.g. an empty draft swiped
            // away); a bare `dismiss` would then dismiss the posts page itself if it happened to be
            // presented.
            if self.presentedViewController != nil {
                self.dismiss(animated: true)
            }
        }
    }

    private lazy var settingsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(primaryAction: UIAction(
            image: UIImage(named: "page-settings"),
            handler: { [unowned self] action in
                let settings = PostsPageSettingsViewController()
                settings.tiltScrollRecalibrate = { [weak self] in
                    self?.postsView.tiltScrollManager.recalibrate()
                }
                self.present(settings, animated: true)

                if let popover = settings.popoverPresentationController {
                    popover.barButtonItem = action.sender as? UIBarButtonItem
                }
            }
        ))
        item.accessibilityLabel = "Settings"
        if !LiquidGlass.isEnabled {
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
        if !LiquidGlass.isEnabled {
            item.tintColor = theme["toolbarTextColor"]
        }
        return item
    }()

    private lazy var pageNumberView: PageNumberView = {
        let view = PageNumberView()
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

        item.accessibilityHint = "Opens page picker"
        return item
    }()

    /// Keeps `currentPageItem`'s representation in sync with the Reduce Liquid Glass setting:
    /// the glass `PageNumberView` pill when glass is on, a plain text title otherwise. Safe to
    /// call repeatedly; only rebuilds when the representation actually changes.
    private func syncCurrentPageItemStyle() {
        if LiquidGlass.isEnabled {
            if currentPageItem.customView == nil {
                let containerView = UIView()
                containerView.addSubview(pageNumberView)
                pageNumberView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    pageNumberView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                    pageNumberView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                    containerView.widthAnchor.constraint(equalTo: pageNumberView.widthAnchor, constant: 2),
                    containerView.heightAnchor.constraint(equalTo: pageNumberView.heightAnchor, constant: 2)
                ])
                currentPageItem.customView = containerView
                currentPageItem.title = nil
            }
        } else {
            if currentPageItem.customView != nil {
                pageNumberView.removeFromSuperview()
                currentPageItem.customView = nil
            }
            currentPageItem.possibleTitles = ["2345 / 2345"]
        }
    }

    /// Pushes the current page state into whichever representation `currentPageItem` is using.
    private func updateCurrentPageItemDisplay() {
        if case .specific(let pageNumber)? = page, numberOfPages > 0 {
            if LiquidGlass.isEnabled {
                pageNumberView.currentPage = pageNumber
                pageNumberView.totalPages = numberOfPages
            } else {
                currentPageItem.title = "\(pageNumber) / \(numberOfPages)"
                currentPageItem.setTitleTextAttributes([.font: UIFont.preferredFontForTextStyle(.body, weight: .regular, maximumPointSize: PageNumberView.maximumFontPointSize)], for: .normal)
            }
            currentPageItem.accessibilityLabel = "Page \(pageNumber) of \(numberOfPages)"
        } else {
            if LiquidGlass.isEnabled {
                pageNumberView.currentPage = 0
                pageNumberView.totalPages = 0
            } else {
                currentPageItem.title = ""
            }
            currentPageItem.accessibilityLabel = nil
        }
    }

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
        if !LiquidGlass.isEnabled {
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
        if !LiquidGlass.isEnabled {
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
            logger.error("\(#function) error fetching posts: \(error)")
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

        if pullForNext || endlessScrollPosts {
            if case .specific(let pageNumber)? = page, numberOfPages > pageNumber {
                if endlessScrollPosts {
                    // Endless scroll replaces the pull-for-next arrow; the near-bottom trigger loads the next page instead.
                    postsView.refreshControl = nil
                } else if !(postsView.refreshControl is PostsPageRefreshArrowView) {
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

        updateCurrentPageItemDisplay()

        forwardItem.isEnabled = {
            switch page {
            case .specific(let pageNumber)?:
                return pageNumber < numberOfPages
            case .last?, .nextUnread?, nil:
                return false
            }
        }()

        composeItem.isEnabled = !thread.closed && !isArchivesMode

        updateToolbarItems()
    }
    
    private func updateToolbarItems() {
        syncCurrentPageItemStyle()
        updateCurrentPageItemDisplay()

        let actions = actionsItem()
        let buttonItems: [UIBarButtonItem]
        if endlessScrollPosts {
            buttonItems = [settingsItem, actions]
            postsView.toolbarItems = [settingsItem, .flexibleSpace(), actions]
        } else {
            buttonItems = [settingsItem, backItem, currentPageItem, forwardItem, actions]
            postsView.toolbarItems = [settingsItem, .flexibleSpace(), backItem, currentPageItem, forwardItem, .flexibleSpace(), actions]
        }

        if #available(iOS 26.0, *) {
            // Only the real buttons: touching the flexible spaces makes them join the shared
            // glass background, which merges every platter into one full-width pill.
            let hide = !LiquidGlass.isEnabled
            for item in buttonItems {
                item.hidesSharedBackground = hide
            }
        }
    }

    private func showLoadingView() {
        guard postsView.loadingView == nil else { return }
        postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
    }

    private func clearLoadingMessage() {
        loadingHoldTask?.cancel()
        loadingHoldTask = nil
        postsView.loadingView = nil
    }

    /// Dismisses the loading view after a render or image-load completes, but if the first
    /// visible posts contain embeds, keeps it up for `loadingHoldDuration` so the embeds can
    /// reflow behind the throbber. Restoration can render twice (cached then network);
    /// restarting the hold on each render keeps the view up across that transition.
    private func dismissLoadingViewAfterRender() {
        guard postsView.loadingView != nil else { return }
        guard firstVisiblePostsContainEmbed() else {
            clearLoadingMessage()
            return
        }
        loadingHoldTask?.cancel()
        loadingHoldTask = Task { [weak self] in
            try? await Task.sleep(timeInterval: Self.loadingHoldDuration)
            guard let self, !Task.isCancelled else { return }
            self.clearLoadingMessage()
        }
    }

    /// Whether any of the first visible posts links to a tweet or Bluesky post that we'd embed.
    /// A cheap substring scan (not the full HTMLReader pass) — good enough to decide whether to
    /// briefly hold the loading view.
    private func firstVisiblePostsContainEmbed() -> Bool {
        guard embedTweets || embedBlueskyPosts else { return false }
        for post in posts.dropFirst(hiddenPosts).prefix(Self.embedScanPostCount) {
            guard let html = post.innerHTML else { continue }
            if embedTweets, html.contains("/status/"), html.contains("twitter.com/") || html.contains("x.com/") {
                return true
            }
            if embedBlueskyPosts, html.contains("bsky.app/"), html.contains("/post/") {
                return true
            }
        }
        return false
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

    /// Endless scroll: fetches the next page and appends its posts to the rendered document, preceded by a "Page x of y" divider. Called repeatedly as the user scrolls near the bottom; all gating happens here so calls are cheap and idempotent.
    func appendNextPageIfNeeded() {
        guard endlessScrollPosts,
              appendTask == nil,
              postsView.loadingView == nil,
              webViewDidLoadOnce,
              case .specific(let currentPage)? = page,
              currentPage < numberOfPages
        else { return }

        let nextPage = currentPage + 1
        let thread = self.thread
        let author = self.author
        var task: Task<Void, Never>?
        task = Task { [weak self] in
            // Clear the gate only if it's still ours: a cancelled task finishing late must not
            // clobber the handle of a newer append that `loadPage` kicked off in the meantime.
            defer { if self?.appendTask == task { self?.appendTask = nil } }
            do {
                let result = try await ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: .specific(nextPage), updateLastReadPost: true)
                guard let self, !Task.isCancelled,
                      self.endlessScrollPosts,
                      // Bail if a loadPage raced us and the document no longer ends with the page we appended after.
                      self.page == .specific(currentPage),
                      !result.posts.isEmpty
                else { return }

                self.posts.append(contentsOf: result.posts)
                self.page = .specific(nextPage)
                self.endlessScrollDidAppend = true

                var html = ""
                for (i, post) in result.posts.enumerated() {
                    var context = PostRenderModel(post).context
                    if i == 0 {
                        context["pageDivider"] = "Page \(nextPage) of \(self.numberOfPages)"
                    }
                    do {
                        html += try StencilEnvironment.shared.renderTemplate(.post, context: context)
                    } catch {
                        logger.error("could not render appended post \(post.postID): \(error)")
                    }
                }
                // On the last page, restore the end-of-thread marker (the frog spacer / "End of the thread"), which normally comes from the full-document template.
                var endHTML: String?
                if nextPage >= self.numberOfPages {
                    endHTML = self.frogAndGhostEnabled
                        ? #"<div id="endf" class=".end" style="height: 100px;"></div>"#
                        : #"<div id="end" class=".end">End of the thread</div>"#
                }
                await self.postsView.renderView.appendPostHTML(html, endHTML: endHTML)
                if self.embedBlueskyPosts {
                    self.postsView.renderView.embedBlueskyPosts()
                }

                if let lastPost = result.posts.last, self.thread.seenPosts < lastPost.threadIndex {
                    self.thread.seenPosts = lastPost.threadIndex
                }
                self.updateUserInterface()
                self.configureUserActivityIfPossible()
            } catch {
                // Stay quiet; scrolling near the bottom again retries.
                logger.error("endless scroll could not load page \(nextPage): \(error)")
            }
        }
        appendTask = task
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
            popover.sourceView = pageNumberView
            popover.sourceRect = pageNumberView.bounds
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
        // Defensive: if `posts` was replaced out from under a nonzero `hiddenPosts`, reveal
        // what's actually there rather than trap.
        let end = min(hiddenPosts, posts.count)
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
        guard posts.indices.contains(postIndex + hiddenPosts) else {
            logger.error("post \(postIndex) beyond range (hiding \(self.hiddenPosts) posts)")
            return
        }
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
                let theirPostsAction = UIAction(title: "Their posts ITT",
                                                image: UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate),
                                                identifier: theirPosts,
                                                handler: theirPosts(action:))
                userActions.append(theirPostsAction)
            }
            // Their posts everywhere
            let theirPostsEverywhere = UIAction.Identifier("theirPostsEverywhere")
            let theirPostsEverywhereAction = UIAction(title: "All their posts",
                                                      image: UIImage(systemName: "text.magnifyingglass"),
                                                      identifier: theirPostsEverywhere,
                                                      handler: theirPostsEverywhere(action:))
            userActions.append(theirPostsEverywhereAction)
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
            guard let workspace = self.replyWorkspace, let post = self.selectedPost else { return }

            // Present the compose sheet before fetching, so the quote is always inserted where the
            // user can see it.
            self.showReplyWorkspace()

            self.quoteFetchTask?.cancel()
            self.quoteFetchTask = Task { @MainActor [weak self] in
                do {
                    try await workspace.quotePost(post)
                } catch is CancellationError {
                    // Quote is no longer wanted; nothing to do.
                } catch {
                    guard let self else { return }
                    let alert = UIAlertController(networkError: error)
                    (self.presentedViewController ?? self).present(alert, animated: true)
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
                            self.replyWorkspace?.forgetDraft()
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
            postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)

            self.navigationController?.pushViewController(postsVC, animated: true)

        }
    }

    private func searchThread(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) { [self] in
            showSearch(SearchFormViewController.makeStack(threadID: thread.threadID, handlers: .awful))
        }
    }

    private func lastSearchResults(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) { [self] in
            // Results already in that stack are the ones the reader came from, so go back to those
            // rather than fetching a second copy on top.
            if let nav = searchHostNavigationController,
               let existing = nav.viewControllers.last(where: { $0 is SearchResultsViewController })
            {
                nav.popToViewController(existing, animated: true)
                splitViewController?.showPrimaryViewController()
                return
            }
            guard let record = LastSearchStore.record else { return }
            showSearch(SearchFormViewController.makeStack(restoring: record, handlers: .awful))
        }
    }

    private func showSearch(_ screens: [UIViewController]) {
        guard let nav = searchHostNavigationController else { return }
        SearchFormViewController.push(screens, onto: nav)
        splitViewController?.showPrimaryViewController()
    }

    /// The navigation stack the search screens should live in.
    ///
    /// Usually this posts page's own stack. The exception is an expanded split view, where this
    /// posts page sits in the detail column: opening a result there calls
    /// `showDetailViewController`, which replaces the entire detail stack and would take the search
    /// screens with it. Putting them in the sidebar instead keeps them alive — and visible beside
    /// the post they opened.
    private var searchHostNavigationController: UINavigationController? {
        guard let splitViewController, !splitViewController.isCollapsed else {
            return navigationController
        }
        guard let tabBarController = splitViewController.viewControllers.first as? UITabBarController
        else { return navigationController }
        return tabBarController.selectedViewController as? UINavigationController ?? navigationController
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

    private func viewPoll(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            // The menu is anchored to a hidden button that has to go away before we present.
            await dismiss(animated: false)
            presentPollViewer()
        }
    }

    private func presentPollViewer() {
        guard let poll else { return }
        let viewer = PollViewerHostingController(poll: poll, theme: theme, handlers: .awful) { [weak self] voted in
            // Hold onto the fresher copy so reopening the sheet doesn't offer a ballot we've used.
            self?.poll = voted
        }
        present(viewer, animated: true)
    }

    /// Offers the poll toast the first time this thread is opened, and never again for it: the
    /// "View poll" item in the thread actions menu is the way back to a poll after that.
    ///
    /// Called from every render. Rendering happens twice on a typical load — once from the cached
    /// posts, then again once the network comes back — and only the second one knows about a poll.
    /// Hence the ordering here: checking `poll` *before* spending `hasOfferedPollToast` means the
    /// cached render doesn't burn the one check we do per visit.
    private func offerPollToastIfNeeded() {
        guard !hasOfferedPollToast, poll != nil else { return }
        hasOfferedPollToast = true

        let store = OfferedPollToastStore.shared
        guard !store.hasOffered(threadID: thread.threadID) else { return }
        store.markOffered(threadID: thread.threadID)

        BannerToastView.show(
            in: view,
            theme: theme,
            message: "This thread has a poll",
            action: .link(text: "has a poll", actionName: "View poll"),
            duration: 6,
            bottomInset: pollToastBottomInset
        ) { [weak self] in
            self?.presentPollViewer()
        }
    }

    /// How far up from the safe area the toast needs to sit to clear the posts toolbar, which lives
    /// inside `postsView` and so contributes nothing to `view`'s safe area.
    ///
    /// This is the toolbar's overlap with the safe area specifically — the banner is pinned to the
    /// safe-area bottom, so measuring from the view's bottom edge instead would double-count the
    /// home indicator. Read once, when the toast appears: if immersive mode later hides the toolbar
    /// the banner just sits a little high, which is fine for the few seconds it's up.
    private var pollToastBottomInset: CGFloat {
        let toolbarTop = postsView.convert(postsView.toolbar.frame, to: view).minY
        return max(0, view.safeAreaLayoutGuide.layoutFrame.maxY - toolbarTop)
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
            postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
            self.navigationController?.pushViewController(postsVC, animated: true)
        }
    }

    private func theirPostsEverywhere(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.dismiss(animated: false) { [self] in
            guard let username = selectedUser?.username, !username.isEmpty else { return }
            showSearch([SearchResultsViewController.immediateSearch(
                query: "username:\"\(username)\"",
                handlers: .awful
            )])
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
            self.present(messageVC.enclosingNavigationController, animated: true, completion: nil)
        }
    }

    private func rapSheet(action: UIAction) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        self.dismiss(animated: false) {
            let rapSheetVC = RapSheetViewController(user: self.selectedUser!, handlers: .awful)
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
                    guard let selectedPost = selectedPost else {
                        logger.error("Cannot edit: no post selected")
                        return
                    }

                    let text = try await ForumsClient.shared.findBBcodeContents(of: selectedPost)
                    let capabilities = try? await ForumsClient.shared.findEditAttachmentCapabilities(for: selectedPost)

                    @MainActor func makeConfiguredWorkspace() async -> ReplyWorkspace {
                        let replyWorkspace = ReplyWorkspace(post: selectedPost, bbcode: text)

                        // Set attachment info and capabilities before creating the composition view controller
                        if let editDraft = replyWorkspace.draft as? EditReplyDraft {
                            editDraft.canAddAttachment = capabilities?.canAddAttachment ?? false

                            if let attachmentInfo = capabilities?.existingAttachment {
                                editDraft.existingAttachmentInfo = attachmentInfo

                                do {
                                    let imageData = try await ForumsClient.shared.fetchAttachmentImageByID(attachmentID: attachmentInfo.id)
                                    if let image = UIImage(data: imageData) {
                                        editDraft.existingAttachmentImage = image
                                    }
                                } catch {
                                    logger.error("Failed to fetch attachment image for edit: \(error)")
                                    let alert = UIAlertController(
                                        title: nil,
                                        message: LocalizedString("posts-page.error.attachment-preview-failed"),
                                        preferredStyle: .alert
                                    )
                                    present(alert, animated: true)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        alert.dismiss(animated: true)
                                    }
                                }
                            }
                        }

                        replyWorkspace.completion = replyCompletionBlock
                        return replyWorkspace
                    }

                    let replyWorkspace = await makeConfiguredWorkspace()
                    self.replyWorkspace = replyWorkspace

                    if replyWorkspace.restoredSavedEditDraft {
                        // The saved draft differs from the post's current contents; don't silently
                        // pick one over the other.
                        self.presentDraftMenu(
                            from: .view(self.postsView.renderView, sourceRect: self.selectedFrame!),
                            options: .init(
                                continueEditing: {
                                    self.showReplyWorkspace()
                                },
                                deleteDraft: {
                                    replyWorkspace.forgetDraft()
                                    Task { @MainActor in
                                        self.replyWorkspace = await makeConfiguredWorkspace()
                                        self.showReplyWorkspace()
                                    }
                                })
                        )
                    } else {
                        showReplyWorkspace()
                    }
                } catch {
                    let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-edit-post"), error: error)
                    present(alert, animated: true)
                }
            }
        }

        switch self.replyWorkspace?.status {
        case .editing(let post) where post.postID == selectedPost?.postID:
            // Already editing this very post (the sheet is probably minimized); just bring it back
            // instead of asking about the draft.
            showReplyWorkspace()

        case .editing, .replying:
            self.presentDraftMenu(
                from: .view(self.postsView.renderView, sourceRect: self.selectedFrame!),
                options: .init(deleteDraft: { [weak self] in
                    self?.replyWorkspace?.forgetDraft()
                    presentNewReplyWorkspace()
                })
            )

        case nil:
            presentNewReplyWorkspace()
        }
    }

    private func didTapActionButtonWithRect(
        _ frame: CGRect,
        forPostAtIndex postIndex: Int
    ) {
        guard posts.indices.contains(postIndex + hiddenPosts) else {
            logger.error("post \(postIndex) beyond range (hiding \(self.hiddenPosts) posts)")
            return
        }
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
            if !thread.closed && !isArchivesMode {
                postActions.append(.init(
                    title: "Quote",
                    image: UIImage(named: "quote-post")!.withRenderingMode(.alwaysTemplate),
                    identifier: .init("quote"),
                    handler: quote(action:)
                ))
            }

            // Copy post
            if thread.closed || isArchivesMode {
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
        guard replyWorkspace != nil else {
            return assertionFailure("No reason to show draft menu")
        }
        let title = "Keep draft for \(thread.title ?? "")?"

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

    /// The forum page a post lives on, respecting the single-user filter.
    private func pageNumber(of post: Post) -> Int {
        author == nil ? post.page : post.singleUserPage
    }

    /// The page `posts` starts on. After endless-scroll appends this is the page whose posts
    /// the `hiddenPosts` prefix describes; `page` has moved on to the last appended page.
    private var firstLoadedPage: ThreadPage? {
        posts.first.map { .specific(pageNumber(of: $0)) }
    }

    /// The page a restoration payload should name: after endless-scroll appends, the page of the
    /// topmost-visible post rather than `page` (the last appended one), so restoration lands on
    /// the anchor and `hiddenPosts` isn't applied to a different page's posts.
    private var restorationPage: ThreadPage? {
        guard endlessScrollDidAppend,
              let anchorID = cachedAnchorPostID,
              let anchorPost = posts.first(where: { $0.postID == anchorID })
        else { return page }
        return .specific(pageNumber(of: anchorPost))
    }

    var restorationRoute: AwfulRoute? {
        guard let page = restorationPage, case .specific = page else { return nil }
        if let author = author {
            return .threadPageSingleUser(threadID: thread.threadID, userID: author.userID, page: page, .seen)
        } else {
            return .threadPage(threadID: thread.threadID, page: page, .seen)
        }
    }

    var currentScrollFraction: CGFloat? {
        guard isViewLoaded else { return nil }
        // After appends the fraction describes the multi-page document, not the single page
        // restoration loads; the anchor carries position instead.
        guard !endlessScrollDidAppend else { return nil }
        return postsView.renderView.scrollView.fractionalContentOffset.y
    }

    /// `hiddenPosts` indexes the first loaded page's posts, so it only travels with a payload
    /// that restores that page.
    var currentHiddenPosts: Int {
        restorationPage == firstLoadedPage ? hiddenPosts : 0
    }

    var currentScrollAnchor: (postID: String, deltaY: CGFloat)? {
        if let postID = cachedAnchorPostID, let delta = cachedAnchorDeltaY {
            return (postID, delta)
        }
        return nil
    }

    /// Caches the topmost-visible post asynchronously; read synchronously when iOS asks
    /// for a state-restoration activity.
    func refreshRestorationAnchor() {
        refreshAnchorTask?.cancel()
        refreshAnchorTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.postsView.renderView.topVisiblePost()
            if Task.isCancelled { return }
            if let result {
                self.cachedAnchorPostID = result.postID
                self.cachedAnchorDeltaY = result.deltaY
            } else {
                self.cachedAnchorPostID = nil
                self.cachedAnchorDeltaY = nil
            }
        }
    }

    /// Stages restoration state to apply once the WKWebView finishes rendering. The anchor
    /// is preferred over `scrollFraction` (kept as fallback for activities from older builds).
    func prepareForRestoration(
        scrollFraction: CGFloat?,
        hiddenPosts: Int?,
        anchorPostID: String? = nil,
        anchorDelta: CGFloat? = nil
    ) {
        if let anchorPostID {
            anchorPostIDAfterLoading = anchorPostID
            anchorDeltaAfterLoading = anchorDelta
        }
        if let scrollFraction = scrollFraction {
            scrollToFractionAfterLoading = scrollFraction
            // The URL router already kicked off `loadPage(updatingCache: true)`, which renders
            // cached posts immediately and then re-renders when the network fetch completes —
            // and that completion would otherwise overwrite the scroll fraction we just staged.
            suppressNextScrollFractionPreservation = true
        }
        if let hiddenPosts = hiddenPosts {
            hiddenPostsAfterLoading = hiddenPosts
        }
    }

    /// Abandons any staged scroll-restoration target so user scrolling isn't fought by
    /// re-anchoring when embeds finish loading. Called when the user begins dragging, after
    /// which their scroll position wins for the rest of the page's lifetime.
    func cancelPendingScrollRestoration() {
        jumpToPostIDAfterLoading = nil
        anchorPostIDAfterLoading = nil
        anchorDeltaAfterLoading = nil
        scrollToFractionAfterLoading = nil
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
        guard let route = restorationRoute else { return }

        activity.route = route
        activity.title = thread.title

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }

    override func themeDidChange() {
        super.themeDidChange()

        postsView.themeDidChange(theme)

        // The banner's colors are baked in when it's created, so build a fresh one for the new
        // theme.
        if minimizedDraftBanner != nil {
            setMinimizedDraftBarVisible(true)
        }

        navigationItem.titleLabel.text = title
        navigationItem.titleLabel.font = fontForPostTitle(from: theme, idiom: UIDevice.current.userInterfaceIdiom)

        if UIDevice.current.userInterfaceIdiom == .phone {
            navigationItem.titleLabel.numberOfLines = 2
        }

        if #available(iOS 26.0, *), LiquidGlass.isEnabled {
            navigationItem.updateTitleLabelTextColor(
                forScrollProgress: postsView.renderView.scrollView.navigationBarScrollProgress,
                theme: theme
            )
            configureNavigationBarForLiquidGlass()
        } else {
            navigationItem.titleLabel.textColor = Theme.defaultTheme()[uicolor: "navigationBarTextColor"] ?? .label
        }

        // Update navigation bar button colors (only when the system isn't drawing glass buttons)
        if !LiquidGlass.isEnabled {
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
        if #available(iOS 26.0, *), LiquidGlass.isEnabled, postsView.toolbar.isTranslucent {
            appearance.configureWithDefaultBackground()
        } else {
            // Force opaque on iOS <26. Otherwise the toolbar renders
            // translucent on iPad iOS 18 and post content bleeds through.
            postsView.toolbar.isTranslucent = false
            appearance.configureWithOpaqueBackground()
        }
        appearance.backgroundColor = Theme.defaultTheme()["backgroundColor"]
        appearance.shadowImage = nil
        appearance.shadowColor = nil

        postsView.toolbar.standardAppearance = appearance
        postsView.toolbar.compactAppearance = appearance
        postsView.toolbar.scrollEdgeAppearance = appearance
        postsView.toolbar.compactScrollEdgeAppearance = appearance
        postsView.toolbar.setNeedsLayout()
        postsView.toolbar.layoutIfNeeded()

        if #available(iOS 26.0, *) {
            // iOS 26 toolbars ignore the opaque appearance (items get glass platters over a
            // transparent bar), so paint the legacy background ourselves when glass is disabled.
            postsView.toolbar.setLegacyOpaqueBackground(
                color: LiquidGlass.isEnabled ? nil : Theme.defaultTheme()["backgroundColor"]
            )
        }

        if !LiquidGlass.isEnabled {
            backItem.tintColor = theme["toolbarTextColor"]
            forwardItem.tintColor = theme["toolbarTextColor"]
            settingsItem.tintColor = theme["toolbarTextColor"]
            pageNumberView.textColor = theme["toolbarTextColor"] ?? UIColor.systemBlue
        }

        pageNumberView.updateTheme()

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

        postsView.immersiveModeManager.configure(
            postsView: postsView,
            navigationController: navigationController,
            renderView: postsView.renderView,
            toolbar: postsView.toolbar,
            topBarContainer: postsView.topBarContainer
        )

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

        $hidePostMetadataForReader
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.postsView.renderView.setHidePostMetadataForReader($0) }
            .store(in: &cancellables)

        $endlessScrollPosts
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                self.updateUserInterface()
                // The user may already be parked at the bottom when they turn endless scroll on.
                if enabled { self.appendNextPageIfNeeded() }
            }
            .store(in: &cancellables)

        $pullForNext
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateUserInterface() }
            .store(in: &cancellables)

        // Entering or leaving the archives changes whether replying is possible, so refresh the
        // compose button without waiting for a page load.
        NotificationCenter.default.publisher(for: ForumsClient.archivesTimeframeDidChange)
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

    /// Safely retrieves font configuration from the theme with fallback defaults
    private func fontForPostTitle(from theme: Theme, idiom: UIUserInterfaceIdiom) -> UIFont {
        let sizeAdjustmentKey = idiom == .pad ? "postTitleFontSizeAdjustmentPad" : "postTitleFontSizeAdjustmentPhone"
        let weightKey = idiom == .pad ? "postTitleFontWeightPad" : "postTitleFontWeightPhone"

        let sizeAdjustment = theme[double: sizeAdjustmentKey] ?? (idiom == .pad ? 0 : -1)
        let weightString = theme[weightKey] ?? "semibold"
        let weight = FontWeight(rawValue: weightString)?.weight ?? .semibold

        return UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: sizeAdjustment, weight: weight)
    }

    @available(iOS 26.0, *)
    private func configureNavigationBarForLiquidGlass() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        guard let navController = navigationController as? NavigationController else { return }

        // Hide the custom bottom border from NavigationBar for liquid glass effect
        if let awfulNavigationBar = navigationBar as? NavigationBar {
            awfulNavigationBar.bottomBorderColor = .clear
            // Keep the glass platters' trait in lockstep with the forum theme when this
            // method restyles the bar outside NavigationController's willShow path.
            awfulNavigationBar.overrideUserInterfaceStyle = theme.userInterfaceStyle
        }
        // Start with opaque background - NavigationController will handle the transition to clear on scroll
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme["navigationBarTintColor"]
        appearance.shadowColor = nil
        appearance.shadowImage = nil

        let textColor: UIColor = theme["navigationBarTextColor"] ?? .label
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

        // Set tintColor AFTER applying appearance to ensure back button uses theme color
        let navTextColor: UIColor = theme["mode"] == "dark" ? .white : .black
        navigationBar.tintColor = navTextColor

        // Force the navigation controller to start at scroll position 0 (top)
        // This will also update tintColor based on scroll position if needed
        navController.updateNavigationBarTintForScrollProgress(NSNumber(value: 0.0))

        navigationBar.setNeedsLayout()

        if let previousVC = navigationController?.viewControllers.dropLast().last {
            previousVC.navigationItem.backBarButtonItem?.tintColor = navTextColor
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 26.0, *), LiquidGlass.isEnabled {
            // Style the bar before the push animates, not from `title`'s setter, which landed
            // mid-transition and rebuilt the bar under the animating back button.
            configureNavigationBarForLiquidGlass()
            // Reappearing over a scrolled page (e.g. after a modal) keeps the transparent bar.
            postsView.syncNavigationBarScrollProgress()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        configureUserActivityIfPossible()
        postsView.tiltScrollManager.viewDidAppear()

        // Surface any saved reply draft for this thread as a minimized draft banner, so drafts are
        // discoverable instead of silently waiting behind the reply button. Done here rather than
        // `viewDidLoad` so the banner's toolbar-clearing inset is measured from real layout.
        if !hasSurfacedSavedDraft {
            hasSurfacedSavedDraft = true
            if replyWorkspace == nil,
               let savedDraft = DraftStore.sharedStore().loadDraft("replies/\(thread.threadID)") as? NewReplyDraft,
               let savedText = savedDraft.text, savedText.length > 0
            {
                replyWorkspace = ReplyWorkspace(thread: thread)
                replyWorkspace?.completion = replyCompletionBlock
                setMinimizedDraftBarVisible(true)
            }
        }
    }

    private var hasSurfacedSavedDraft = false

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        postsView.immersiveModeManager.exitImmersiveMode()
        postsView.tiltScrollManager.viewWillDisappear()

        // `navigationController` is nil by `viewDidDisappear`, so grab it now for the
        // leaving-with-a-draft prompt.
        if isMovingFromParent {
            departingNavigationController = navigationController
        }
    }

    private weak var departingNavigationController: UINavigationController?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        userActivity = nil

        // Leaving the thread with a draft in progress: offer the same save/delete choice as the
        // compose sheet's Cancel button, from whatever screen we landed on.
        if isMovingFromParent, let workspace = replyWorkspace {
            quoteFetchTask?.cancel()
            replyWorkspace = nil
            if var presenter = departingNavigationController?.topViewController {
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                workspace.promptToKeepDraft(from: presenter)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            postsView.renderView.jumpToPost(identifiedBy: postID, topOffset: postsView.topInsetForPostFraming)
        } else if let anchorID = anchorPostIDAfterLoading,
                  posts.contains(where: { $0.postID == anchorID })
        {
            // (chrome - deltaY) reproduces the saved scroll position. Staged values stay
            // set so the tweet-loaded callback can re-apply after layout shifts.
            let delta = anchorDeltaAfterLoading ?? 0
            postsView.renderView.jumpToPost(
                identifiedBy: anchorID,
                topOffset: postsView.topInsetForPostFraming - delta
            )
        } else if let newFractionalOffset = scrollToFractionAfterLoading {
            var fractionalOffset = postsView.renderView.scrollView.fractionalContentOffset
            fractionalOffset.y = newFractionalOffset
            postsView.renderView.scrollToFractionalOffset(fractionalOffset)
        }

        dismissLoadingViewAfterRender()

        // Capture an initial anchor so backgrounding before any scroll still produces an anchored save.
        refreshRestorationAnchor()

        offerPollToastIfNeeded()
    }

    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
            didTapUserHeaderWithRect(message.frame, forPostAtIndex: message.postIndex)

        case let message as RenderView.BuiltInMessage.DidTapPostActionButton:
            didTapActionButtonWithRect(message.frame, forPostAtIndex: message.postIndex)

        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            if let postID = jumpToPostIDAfterLoading {
                postsView.renderView.jumpToPost(identifiedBy: postID, topOffset: postsView.topInsetForPostFraming)
            } else if let anchorID = anchorPostIDAfterLoading,
                      posts.contains(where: { $0.postID == anchorID })
            {
                // Re-anchor to the same stable post on every tweet-settle so the viewport
                // stays put as embeds reflow. We deliberately keep the staged anchor set
                // (rather than clearing it after the first event) so later widget loads
                // don't fall through to the drifting fraction fallback below. The staged
                // target is abandoned in `cancelPendingScrollRestoration()` once the user
                // begins dragging, so this never fights a user scroll.
                let delta = anchorDeltaAfterLoading ?? 0
                postsView.renderView.jumpToPost(
                    identifiedBy: anchorID,
                    topOffset: postsView.topInsetForPostFraming - delta
                )
            } else if let fraction = scrollToFractionAfterLoading, fraction > 0 {
                var offset = postsView.renderView.scrollView.fractionalContentOffset
                offset.y = fraction
                postsView.renderView.scrollToFractionalOffset(offset)
            }

        case let message as RenderView.BuiltInMessage.FetchOEmbedFragment:
            fetchOEmbed(url: message.url, id: message.id)

        case let message as RenderView.BuiltInMessage.ImageLoadProgress:
            if message.total == 0 {
                // No images to load; dismiss (respecting any embed hold).
                dismissLoadingViewAfterRender()
            } else {
                let statusText = "Downloading images: \(message.loaded)/\(message.total)"
                postsView.loadingView?.updateStatus(statusText)

                // Dismiss loading view when all images are done (respecting any embed hold).
                if message.complete {
                    dismissLoadingViewAfterRender()
                }
            }

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
            } else if case let .post(id: postID, _) = route,
                      let i = posts.firstIndex(where: { $0.postID == postID })
            {
                if i < hiddenPosts {
                    showHiddenSeenPosts()
                }
                postsView.renderView.jumpToPost(identifiedBy: postID, animated: true, topOffset: postsView.topInsetForPostFraming)
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

extension PostsPageViewController: RestorableLocation {}

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

        if !thread.closed && !isArchivesMode {
            keyCommands.append(UIKeyCommand(action: #selector(newReply), input: "N", modifierFlags: .command, discoverabilityTitle: "New Reply"))
        }

        return keyCommands
    }
}

extension PostsPageViewController: NavigationBarScrollProgressProviding {
    func resyncNavigationBarScrollProgress() {
        guard #available(iOS 26.0, *), LiquidGlass.isEnabled else { return }
        postsView.syncNavigationBarScrollProgress()
    }
}
