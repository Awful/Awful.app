//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import MobileCoreServices
import MRProgress
import PromiseKit
import WebKit

private let Log = Logger.get()

/// Shows a list of posts in a thread.
final class PostsPageViewController: ViewController {
    private lazy var actionMappings: [UIAction.Identifier: UIActionHandler] = [:]
    var selectedPost: Post? = nil
    var selectedUser: User? = nil
    var selectedFrame: CGRect? = nil
    private var advertisementHTML: String?
    private let author: User?
    private var flagRequest: Cancellable?
    private var jumpToLastPost = false
    var postIndex: Int = 0
    private var jumpToPostIDAfterLoading: String?
    private var messageViewController: MessageComposeViewController?
    private weak var networkOperation: Cancellable?
    private var observers: [NSKeyValueObservation] = []
    private(set) var page: ThreadPage?
    private var replyWorkspace: ReplyWorkspace?
    private var restoringState = false
    private var scrollToFractionAfterLoading: CGFloat?
    let thread: AwfulThread
    private var webViewDidLoadOnce = false
    
    lazy var threadActionsMenu: UIMenu = {
        var threadActions: [UIMenuElement] = []
        
        let bookmarkTitle = self.thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread"
        let bookmarkImage = self.thread.bookmarked ?
        UIImage(named: "remove-bookmark")!.withRenderingMode(.alwaysTemplate)
        :
        UIImage(named: "add-bookmark")!.withRenderingMode(.alwaysTemplate)
        let yourPostsImage = UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate)
        let copyURLImage = UIImage(named: "copy-url")!.withRenderingMode(.alwaysTemplate)
        let voteImage = UIImage(named: "vote")!.withRenderingMode(.alwaysTemplate)
        
        // Bookmark
        let bookmarkIdentifier = UIAction.Identifier("bookmark")
        let bookmarkAction = UIAction(title: bookmarkTitle, image: bookmarkImage, identifier: bookmarkIdentifier, handler: { [unowned self] action in
            bookmark(action: action)
        })
        bookmarkAction.attributes = self.thread.bookmarked ? [.destructive] : []
        threadActions.append(bookmarkAction)
        
        // Copy link
        let copyLinkIdentifier = UIAction.Identifier("copyLink")
        let copyLinkAction = UIAction(title: "Copy link", image: copyURLImage, identifier: copyLinkIdentifier, handler: { [unowned self] action in
            copyLink(action: action)
        })
        threadActions.append(copyLinkAction)
        
        // Vote
        let voteIdentifier = UIAction.Identifier("vote")
        let voteAction = UIAction(title: "Vote", image: voteImage, identifier: voteIdentifier, handler: { [unowned self] action in
            vote(action: action)
        })
        threadActions.append(voteAction)
        
        // Your posts
        let yourPostsIdentifier = UIAction.Identifier("yourPosts")
        let yourPostsAction = UIAction(title: "Your posts", image: yourPostsImage, identifier: yourPostsIdentifier, handler: { [unowned self] action in
            yourPosts(action: action)
        })
        threadActions.append(yourPostsAction)
        
        if #available(iOS 14.0, *) {
            // no op. iOS14+ uses UIMenu, 13 uses Chidori third party menus
        } else {
            actionMappings[bookmarkIdentifier] = bookmark(action:)
            actionMappings[copyLinkIdentifier] = copyLink(action:)
            actionMappings[voteIdentifier] = vote(action:)
            actionMappings[yourPostsIdentifier] = yourPosts(action:)
        }
        
        return UIMenu(title: self.thread.title ?? "", image: nil, identifier: nil, options: [.displayInline], children: threadActions)
    }()
    

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
        postsView.topBar.goToParentForum = { [unowned self] in
            guard let forum = self.thread.forum else { return }
            AppDelegate.instance.open(route: .forum(id: forum.forumID))
        }
        return postsView
    }()

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
        return Theme.currentTheme(for: forum)
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
        flagRequest?.cancel()
        flagRequest = nil
        networkOperation?.cancel()
        networkOperation = nil
        
        // prevent white flash caused by webview being opaque during refreshes
        if #available(iOS 15, *), UserDefaults.standard.isDarkModeEnabled {
            self.postsView.renderView.toggleOpaqueToFixIOS15ScrollThumbColor(setOpaqueTo: false)
            self.postsView.viewHasBeenScrolledOnce = false
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

        let (promise, cancellable) = ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: newPage, updateLastReadPost: updateLastReadPost)
        networkOperation = cancellable

        promise
            .done { [weak self] posts, firstUnreadPost, advertisementHTML in
                guard let self = self else { return }

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
                    self.currentPageItem.title = "Page ? of \(pageCount)"

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
            }
            .catch { [weak self] error in
                guard let self = self else { return }

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
                    let pageCount = self.numberOfPages > 0 ? "\(self.numberOfPages)" : "?"
                    self.currentPageItem.title = "Page ? of \(pageCount)"

                case .last, .nextUnread, .specific:
                    break
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
    
    private func renderPosts() {
        webViewDidLoadOnce = false
        
        var context: [String: Any] = [:]
        
        context["stylesheet"] = theme[string: "postsViewCSS"] as Any
        
        if posts.count > hiddenPosts {
            let subset = posts[hiddenPosts...]
            context["posts"] = subset.map { PostRenderModel($0).context }
        }
        
        if let ad = advertisementHTML, !ad.isEmpty {
            context["advertisementHTML"] = ad
        }
        
        if context["posts"] != nil, case .specific(let pageNumber)? = page, pageNumber >= numberOfPages {
            context["endMessage"] = true
        }
        
        context["enableFrogAndGhost"] = UserDefaults.standard.enableFrogAndGhost
        
        context["ghostJsonData"] = try? String(contentsOf: URL(string: "ghost.json", relativeTo: Bundle.main.resourceURL)!, encoding: .utf8)
      
        if let username = UserDefaults.standard.loggedInUsername, !username.isEmpty {
            context["loggedInUsername"] = username
        }
        
        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet
        
        if !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID
        }
        
        if let forum = thread.forum, !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }

        context["tweetTheme"] = theme[string: "postsTweetTheme"] ?? "light"

        let html: String
        do {
            html = try StencilEnvironment.shared.renderTemplate(.postsView, context: context)
        } catch {
            Log.e("could not render posts view HTML: \(error)")
            html = ""
        }
        
        postsView.renderView.eraseDocument().done {
            self.postsView.renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
        }
    }
    
    private lazy var composeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(compose))
        item.accessibilityLabel = NSLocalizedString("compose.accessibility-label", comment: "")
        return item
    }()

    @IBAction private func compose(
        _ sender: UIBarButtonItem,
        forEvent event: UIEvent
    ) {
        if UserDefaults.standard.enableHaptics {
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
        let item = UIBarButtonItem(image: UIImage(named: "page-settings"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Settings"
        item.actionBlock = { [unowned self] (sender) in
            let settings = PostsPageSettingsViewController()
            self.present(settings, animated: true)
            
            if let popover = settings.popoverPresentationController {
                popover.barButtonItem = sender
            }
        }
        return item
    }()
    
    private lazy var backItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "arrowleft"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Previous page"
        item.actionBlock = { [unowned self] (sender) in
            guard case .specific(let pageNumber)? = self.page, pageNumber > 1 else { return }
            if UserDefaults.standard.enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            self.loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    private lazy var currentPageItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        item.possibleTitles = ["2345 / 2345"]
        item.accessibilityHint = "Opens page picker"
        item.actionBlock = { [unowned self] (sender) in
            guard self.postsView.loadingView == nil else { return }
            let selectotron = Selectotron(postsViewController: self)
            self.present(selectotron, animated: true, completion: nil)
            
            if let popover = selectotron.popoverPresentationController {
                popover.barButtonItem = sender
            }
        }
        return item
    }()
    
    private lazy var forwardItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "arrowright"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Next page"
        item.actionBlock = { [unowned self] (sender) in
            guard case .specific(let pageNumber)? = self.page, pageNumber < self.numberOfPages, pageNumber > 0 else { return }
            if UserDefaults.standard.enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            self.loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    
    private lazy var actionsItem: UIBarButtonItem = {
        var item: UIBarButtonItem
        if #available(iOS 14.0, *) {
            item = UIBarButtonItem(title: "Menu", image: UIImage(named: "steamed-ham"), primaryAction: nil, menu: threadActionsMenu)
        } else {
            item = UIBarButtonItem(image: UIImage(named: "steamed-ham"), style: .plain, target: nil, action: #selector(didTapHamburgerMenu))
        }
        
        return item
    }()
    
    @objc private func externalStylesheetDidUpdate(_ rawNotification: Notification) {
        guard let notification = PostsViewExternalStylesheetLoader.DidUpdateNotification(rawNotification) else {
            return Log.e("got an unexpected or invalid notification: \(rawNotification)")
        }
        
        postsView.renderView.setExternalStylesheet(notification.stylesheet)
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
        title = thread.title?.stringByCollapsingWhitespace
        
        if page == .last || page == .nextUnread || posts.isEmpty {
            showLoadingView()
        }

        postsView.topBar.showPreviousPosts = hiddenPosts == 0 ? nil : { [unowned self] in
            self.showHiddenSeenPosts()
        }
        postsView.topBar.scrollToEnd = posts.isEmpty ? nil : { [unowned self] in
            self.scrollToBottom(nil)
        }

        if UserDefaults.standard.isPullForNextEnabled {
            if case .specific(let pageNumber)? = page, numberOfPages > pageNumber {
                if !(postsView.refreshControl is PostsPageRefreshArrowView) {
                    postsView.refreshControl = PostsPageRefreshArrowView()
                }
            } else {
                if !(postsView.refreshControl is PostsPageRefreshSpinnerView) {
                    if !UserDefaults.standard.enableFrogAndGhost {
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
            currentPageItem.title = "\(pageNumber) / \(numberOfPages)"
            currentPageItem.accessibilityLabel = "Page \(pageNumber) of \(numberOfPages)"
            currentPageItem.setTitleTextAttributes([.font: UIFont.preferredFontForTextStyle(.body, weight: .medium)], for: .normal)
        } else {
            currentPageItem.title = ""
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
    
    @objc private func didTapHamburgerMenu() {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        let chidoriMenu = ChidoriMenu(menu: threadActionsMenu,
                                      summonPoint: CGPoint(x: self.postsView.toolbar.frame.maxX - 80,
                                                           y: self.postsView.toolbar.frame.maxY - 230)
        )
        
        chidoriMenu.delegate = self
        
        present(chidoriMenu, animated: true, completion: nil)
    }
    
    @objc private func loadPreviousPage(_ sender: UIKeyCommand) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard case .specific(let pageNumber)? = page, pageNumber > 1 else { return }
        loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func loadNextPage(_ sender: UIKeyCommand) {
        if UserDefaults.standard.enableHaptics {
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard sender.state == .began else { return }
        
        postsView.renderView.interestingElements(at: sender.location(in: postsView.renderView)).done {
            _ = URLMenuPresenter.presentInterestingElements($0, from: self, renderView: self.postsView.renderView)
        }
    }
    
    @objc private func didDoubleTapOnPostsView(_ sender: UITapGestureRecognizer) {
        postsView.renderView.findPostFrame(at: sender.location(in: postsView.renderView)).done { [postsView] in
            guard let postFrame = $0 else { return }
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
            Log.e("could not render post at index \(i): \(error)")
            return ""
        }
    }
    
    private func readIgnoredPostAtIndex(_ i: Int) {
        let post = posts[i]
        ForumsClient.shared.readIgnoredPost(post)
            .done { [weak self] in
                // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
                guard
                    let self = self,
                    let i = self.posts.firstIndex(of: post)
                    else { return }
                
                self.postsView.renderView.replacePostHTML(self.renderedPostAtIndex(i), at: i - self.hiddenPosts)
            }
            .catch { [weak self] error in
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
        }
    }
    
    private func didTapUserHeaderWithRect(_ frame: CGRect, forPostAtIndex postIndex: Int) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.selectedPost = posts[postIndex + hiddenPosts]
        self.selectedFrame = frame
        
        var postActions: [UIMenuElement] = []
        guard let user = self.selectedPost!.author else { return }
        self.selectedUser = user
        
        let postActionMenu: UIMenu = {
            // Profile
            let profile = UIAction.Identifier("profile")
            actionMappings[profile] = profile(action:)
            let profileAction = UIAction(title: "Profile",
                                         image: UIImage(named: "user-profile")!.withRenderingMode(.alwaysTemplate),
                                         identifier: profile,
                                         handler: profile(action:))
            postActions.append(profileAction)
            
            // Their posts
            if author == nil {
                let theirPosts = UIAction.Identifier("theirPosts")
                actionMappings[theirPosts] = theirPosts(action:)
                let theirPostsAction = UIAction(title: "Their posts",
                                                image: UIImage(named: "single-users-posts")!.withRenderingMode(.alwaysTemplate),
                                                identifier: theirPosts,
                                                handler: theirPosts(action:))
                postActions.append(theirPostsAction)
            }
            // Private Message
            if UserDefaults.standard.loggedInUserCanSendPrivateMessages &&
                user.canReceivePrivateMessages &&
                user.userID != UserDefaults.standard.loggedInUserID
            {
                let privateMessage = UIAction.Identifier("privateMessage")
                actionMappings[privateMessage] = privateMessage(action:)
                let privateMessageAction = UIAction(title: "Private message",
                                                    image: UIImage(named: "send-private-message")!.withRenderingMode(.alwaysTemplate),
                                                    identifier: privateMessage,
                                                    handler: privateMessage(action:))
                postActions.append(privateMessageAction)
            }
            // Rap Sheet
            let rapSheet = UIAction.Identifier("rapSheet")
            actionMappings[rapSheet] = rapSheet(action:)
            let rapSheetAction = UIAction(title: "Rap sheet",
                                          image: UIImage(named: "rap-sheet")!.withRenderingMode(.alwaysTemplate),
                                          identifier: rapSheet,
                                          handler: rapSheet(action:))
            postActions.append(rapSheetAction)
            
            // Ignore user
            if self.selectedPost!.ignored {
                let ignoreUser = UIAction.Identifier("ignoreUser")
                actionMappings[ignoreUser] = ignoreUser(action:)
                let ignoreAction = UIAction(title: "Unignore user",
                                            image: UIImage(named: "ignore")!.withRenderingMode(.alwaysTemplate),
                                            identifier: ignoreUser,
                                            handler: ignoreUser(action:))
                postActions.append(ignoreAction)
            } else {
                let ignoreUser = UIAction.Identifier("ignoreUser")
                actionMappings[ignoreUser] = ignoreUser(action:)
                let ignoreAction = UIAction(title: "Ignore user",
                                            image: UIImage(named: "ignore")!.withRenderingMode(.alwaysTemplate),
                                            identifier: ignoreUser,
                                            handler: ignoreUser(action:))
                postActions.append(ignoreAction)
            }
            
            let tempMenu = UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: postActions)
            return UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: [tempMenu])
        }()
        
        if UserDefaults.standard.hideSidebarInLandscape, traitCollection.userInterfaceIdiom == .pad {
            let chidoriMenu = ChidoriMenu(menu: postActionMenu, summonPoint: .init(x: 550, y: frame.origin.y))
            chidoriMenu.delegate = self
            
            present(chidoriMenu, animated: true, completion: nil)
        } else {
            let chidoriMenu = ChidoriMenu(menu: postActionMenu, summonPoint: frame.origin)
            chidoriMenu.delegate = self
            
            present(chidoriMenu, animated: true, completion: nil)
        }
    }
    
    
    private func shareURL(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
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
                    UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            ForumsClient.shared.markThreadAsSeenUpTo(self.selectedPost!)
                .done { [weak self] in
                    guard let self = self else { return }
                    
                    self.selectedPost!.thread?.seenPosts = self.selectedPost!.threadIndex
                    self.postsView.renderView.markReadUpToPost(identifiedBy: self.selectedPost!.postID)
                    
                    let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: LocalizedString("posts-page.marked-read"), mode: .checkmark, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        overlay?.dismiss(true)
                    }
                }
                .catch { [weak self] error in
                    guard let self = self else { return }
                    
                    let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-mark-seen"), error: error)
                    self.present(alert, animated: true)
                }
        }
    }
    
    private func quote(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        func makeNewReplyWorkspace() {
            self.replyWorkspace = ReplyWorkspace(thread: self.thread)
            self.replyWorkspace?.completion = self.replyCompletionBlock
        }
        func quotePost() {
            self.replyWorkspace!.quotePost(self.selectedPost!, completion: { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    let alert = UIAlertController(networkError: error)
                    self.present(alert, animated: true)
                    return
                }
                
                if let vc = self.replyWorkspace?.viewController {
                    self.present(vc, animated: true)
                }
            })
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            
            let userKey = UserKey(userID: UserDefaults.standard.loggedInUserID!, username: UserDefaults.standard.loggedInUsername)
            let user = User.objectForKey(objectKey: userKey, in: self.thread.managedObjectContext!)
            
            let postsVC = PostsPageViewController(thread: self.thread, author: user)
            postsVC.restorationIdentifier = "Just your posts"
            postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
            
            self.navigationController?.pushViewController(postsVC, animated: true)
            
            print("Your Posts")
            
        }
    }
    
    private func bookmark(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            ForumsClient.shared.setThread(self.thread, isBookmarked: !self.thread.bookmarked)
                .done { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    let status = strongSelf.thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAdded(to: strongSelf.view, title: status, mode: .checkmark, animated: true)
                    overlay?.tintColor = strongSelf.theme["tintColor"]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        overlay?.dismiss(true)
                    }
                }
                .catch { error in
                    print("\(#function) error marking thread: \(error)")
                }
        }
    }
    
    private func copyLink(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Copied Link", mode: .checkmark, animated: true)
            overlay?.tintColor = self.theme["tintColor"]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                overlay?.dismiss(true)
            }
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
            let url = components.url!
            
            UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
            UIPasteboard.general.coercedURL = url
        }
    }
    
    private func copy(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
            let overlay = MRProgressOverlayView.showOverlayAdded(to: self.postsView.renderView,
                                                                 title: LocalizedString("posts-page.copied-post"),
                                                                 mode: .checkmark,
                                                                 animated: true)
            overlay?.tintColor = self.theme["tintColor"]
            
            ForumsClient.shared.quoteBBcodeContents(of: self.selectedPost!)
                .done { [weak self] bbcode in
                    guard self != nil else { return }
                    UIPasteboard.general.string = bbcode
                }
                .catch { [weak self] error in
                    guard let self = self else { return }
                    let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-copy-post"), error: error)
                    self.present(alert, animated: true)
                }
                .finally {
                    overlay?.dismiss(true)
                }
        }
    }
    
    private func report(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.dismiss(animated: false) {
        let actionSheet = UIAlertController.makeActionSheet()
        for i in stride(from: 5, to: 0, by: -1) {
            actionSheet.addActionWithTitle("\(i)", handler: {
                let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Voting \(i)", mode: .indeterminate, animated: true)
                overlay?.tintColor = self.theme["tintColor"]
                
                ForumsClient.shared.rate(self.thread, as: i)
                    .done {
                        overlay?.mode = .checkmark
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            overlay?.dismiss(true)
                        }
                    }
                    .catch { [weak self] error in
                        
                        overlay?.dismiss(false)
                        
                        let alert = UIAlertController(title: "Vote Failed", error: error)
                        self?.present(alert, animated: true)
                    }
            })
        }
            
        actionSheet.addCancelActionWithHandler(nil)
        self.present(actionSheet, animated: false)
        }
    }
    
    private func profile(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let profileVC = ProfileViewController(user: self.selectedUser!)
        
        self.dismiss(animated: false) {
            self.present(profileVC.enclosingNavigationController, animated: true, completion: nil)
        }
    }
    
    private func theirPosts(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
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
        if UserDefaults.standard.enableHaptics {
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
        if UserDefaults.standard.enableHaptics {
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        self.dismiss(animated: false) {
            // removing ignored users requires username. adding a new user requires userid
            guard let userKey = self.selectedPost!.ignored ? self.selectedUser!.username : self.selectedUser!.userID else { return }
            
            let ignoreBlock: (_ username: String) -> Promise<Void>
            
            if self.selectedPost!.ignored {
                ignoreBlock = ForumsClient.shared.removeUserFromIgnoreList
            } else {
                ignoreBlock = ForumsClient.shared.addUserToIgnoreList
            }
            
            let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Updating Ignore List", mode: .indeterminate, animated: true)
            overlay?.tintColor = self.theme["tintColor"]
            
            ignoreBlock(userKey)
                .done {
                    overlay?.mode = .checkmark
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        overlay?.dismiss(true)
                    }
                }
                .catch { [weak self] error in
                    overlay?.dismiss(false)
                    
                    let alert = UIAlertController(title: "Could Not Update Ignore List", error: error)
                    self?.present(alert, animated: true)
                }
        }
    }
    
    private func edit(action: UIAction) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        func presentNewReplyWorkspace() {
            ForumsClient.shared.findBBcodeContents(of: self.selectedPost!)
                .done { [weak self] text in
                    guard let self = self else { return }
                    let replyWorkspace = ReplyWorkspace(post: self.selectedPost!)
                    self.replyWorkspace = replyWorkspace
                    replyWorkspace.completion = self.replyCompletionBlock
                    self.present(replyWorkspace.viewController, animated: true)
                }
                .catch { [weak self] error in
                    let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-edit-post"), error: error)
                    self?.present(alert, animated: true)
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        var postActions: [UIMenuElement] = []
        
        self.selectedPost = posts[postIndex + hiddenPosts]
        self.selectedFrame = frame
        
        let possessiveUsername: String
        if self.selectedPost!.author?.username == UserDefaults.standard.loggedInUsername {
            possessiveUsername = "Your"
        } else {
            possessiveUsername = "\(self.selectedPost!.author?.username ?? "")'s"
        }
        
        print("\(possessiveUsername)")
        
        let postActionMenu: UIMenu = {
            // Mark Read Up To Here
            if author == nil {
                let markRead = UIAction.Identifier("markread")
                actionMappings[markRead] = markThreadAsSeenUpTo(action:)
                let markreadAction = UIAction(title: "Mark as last read",
                                              image: UIImage(named: "mark-read-up-to-here")!.withRenderingMode(.alwaysTemplate),
                                              identifier: markRead,
                                              handler: markThreadAsSeenUpTo(action:))
                postActions.append(markreadAction)
            } else {
                // Find post
                let findPost = UIAction.Identifier("find")
                actionMappings[findPost] = findPost(action:)
                let findPostAction = UIAction(title: "Find post",
                                              image: UIImage(named: "quick-look")!.withRenderingMode(.alwaysTemplate),
                                              identifier: findPost,
                                              handler: findPost(action:))
                
                postActions.append(findPostAction)
            }
            // edit post
            if self.selectedPost!.editable {
                let edit = UIAction.Identifier("edit")
                actionMappings[edit] = edit(action:)
                let editAction = UIAction(title: "Edit",
                                          image: UIImage(named: "edit-post")!.withRenderingMode(.alwaysTemplate),
                                          identifier: edit,
                                          handler: edit(action:))
                postActions.append(editAction)
            }
            
            // Share URL
            let shareURL = UIAction.Identifier("shareurl")
            actionMappings[shareURL] = shareURL(action:)
            let shareURLAction = UIAction(title: "Share",
                                          image: UIImage(named: "share")!.withRenderingMode(.alwaysTemplate),
                                          identifier: shareURL,
                                          handler: shareURL(action:))
            postActions.append(shareURLAction)
            
            // Quote
            if !thread.closed {
                let quote = UIAction.Identifier("quote")
                actionMappings[quote] = quote(action:)
                let quoteAction = UIAction(title: "Quote",
                                           image: UIImage(named: "quote-post")!.withRenderingMode(.alwaysTemplate),
                                           identifier: quote,
                                           handler: quote(action:))
                postActions.append(quoteAction)
            } else {
                // Copy post
                let copy = UIAction.Identifier("copy")
                actionMappings[copy] = copy(action:)
                let copyAction = UIAction(title: "Copy",
                                          image: UIImage(named: "quote-post")!.withRenderingMode(.alwaysTemplate),
                                          identifier: copy,
                                          handler: copy(action:))
                postActions.append(copyAction)
            }
            // Report
            let report = UIAction.Identifier("report")
            actionMappings[report] = report(action:)
            let reportAction = UIAction(title: "Report",
                                        image: UIImage(named: "rap-sheet")!.withRenderingMode(.alwaysTemplate),
                                        identifier: report,
                                        handler: report(action:))
            postActions.append(reportAction)
            
    
            let tempMenu = UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: postActions)
            return UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: [tempMenu])
        }()
        
        let chidoriMenu = ChidoriMenu(menu: postActionMenu, summonPoint: frame.origin)
        chidoriMenu.delegate = self
        present(chidoriMenu, animated: true, completion: nil)

    }
    
    private func presentDraftMenu(
        from source: DraftMenuSource,
        options: DraftMenuOptions
    ) {
        let title: String
        switch replyWorkspace?.status {
        case let .editing(post) where post.author?.userID == UserDefaults.standard.loggedInUserID:
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
        
        let (promise, cancellable) = ForumsClient.shared.flagForThread(in: forum)
        flagRequest = cancellable
        
        promise
            .compactMap(on: .global()) { flag in
                var components = URLComponents(string: "https://fi.somethingawful.com")!
                components.path = "/flags\(flag.path)"
                if let username = flag.username {
                    components.queryItems = [URLQueryItem(name: "by", value: username)]
                }
                guard let src = components.url else { return nil }
                let title = String(format: LocalizedString("posts-page.fyad-flag-title"), flag.username ?? "", flag.created ?? "")
                return RenderView.FlagInfo(src: src, title: title)
            }
            .done {
                self.postsView.renderView.setFYADFlag($0)
            }
            .catch { error in
                Log.w("could not fetch FYAD flag: \(error)")
                self.postsView.renderView.setFYADFlag(nil)
        }
    }
    
    private func configureUserActivityIfPossible() {
        guard case .specific? = page, UserDefaults.standard.isHandoffEnabled else {
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

        Log.d("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        postsView.themeDidChange(theme)
        navigationItem.titleLabel.textColor = theme["navigationBarTextColor"]
  
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            navigationItem.titleLabel.font = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: .regular)
        default:
            navigationItem.titleLabel.font = UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: .regular)
            navigationItem.titleLabel.numberOfLines = 2
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

        if #available(iOS 15.0, *) {
            postsView.toolbar.scrollEdgeAppearance = appearance
            postsView.toolbar.compactScrollEdgeAppearance = appearance
        }
  
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

        let spacer: CGFloat = 12
        postsView.toolbarItems = [
            settingsItem, .flexibleSpace(),
            backItem, .fixedSpace(spacer), currentPageItem, .fixedSpace(spacer), forwardItem,
            .flexibleSpace(), actionsItem]

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnPostsView))
        longPress.delegate = self
        postsView.renderView.addGestureRecognizer(longPress)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapOnPostsView))
        doubleTap.delegate = self
        doubleTap.numberOfTapsRequired = 2
        postsView.renderView.addGestureRecognizer(doubleTap)
        observers.append(UserDefaults.standard.observeOnMain(\.jumpToPostEndOnDoubleTap, options: .initial) {
            defaults, _ in
            doubleTap.isEnabled = defaults.jumpToPostEndOnDoubleTap
        })
 
        NotificationCenter.default.addObserver(self, selector: #selector(externalStylesheetDidUpdate), name: PostsViewExternalStylesheetLoader.DidUpdateNotification.name, object: PostsViewExternalStylesheetLoader.shared)

        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.embedTweets) { [weak self] defaults in
                guard let self = self else { return }
                if defaults.embedTweets {
                    self.postsView.renderView.embedTweets()
                }
            }
            $0.observe(\.fontScale) { [weak self] defaults in
                guard let self = self else { return }
                self.postsView.renderView.setFontScale(defaults.fontScale)
            }
            $0.observe(\.isHandoffEnabled) { [weak self] defaults in
                guard let self = self else { return }
                if defaults.isHandoffEnabled, self.view.window != nil {
                    self.configureUserActivityIfPossible()
                }
            }
            $0.observe(\.isPullForNextEnabled, options: .initial) { [weak self] defaults in
                guard let self = self else { return }
                self.updateUserInterface()
            }
            $0.observe(\.showAuthorAvatars) { [weak self] defaults in
                guard let self = self else { return }
                self.postsView.renderView.setShowAvatars(defaults.showAuthorAvatars)
            }
            $0.observe(\.showImages) { [weak self] defaults in
                guard let self = self else { return }
                if defaults.showImages {
                    self.postsView.renderView.loadLinkifiedImages()
                }
            }
        }
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
        if UserDefaults.standard.embedTweets {
            view.embedTweets()
        }
        
        if UserDefaults.standard.enableFrogAndGhost {
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
            
        case is FYADFlagRequest:
            fetchNewFlag()
            
        default:
            Log.w("ignoring unexpected JavaScript message: \(type(of: message).messageName)")
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
            UIKeyCommand.make(input: UIKeyCommand.inputUpArrow, action: #selector(scrollUp), discoverabilityTitle: "Up"),
            UIKeyCommand.make(input: UIKeyCommand.inputDownArrow, action: #selector(scrollDown), discoverabilityTitle: "Down"),
            UIKeyCommand.make(input: " ", modifierFlags: .shift, action: #selector(pageUp), discoverabilityTitle: "Page Up"),
            UIKeyCommand.make(input: " ", action: #selector(pageDown), discoverabilityTitle: "Page Down"),
            UIKeyCommand.make(input: UIKeyCommand.inputUpArrow, modifierFlags: .command, action: #selector(scrollToTop), discoverabilityTitle: "Scroll to Top"),
            UIKeyCommand.make(input: UIKeyCommand.inputDownArrow, modifierFlags: .command, action: #selector(scrollToBottom(_:)), discoverabilityTitle: "Scroll to Bottom"),
        ]
        
        if case .specific(let pageNumber)? = page, pageNumber > 1 {
            keyCommands.append(UIKeyCommand.make(input: "[", modifierFlags: .command, action: #selector(loadPreviousPage), discoverabilityTitle: "Previous Page"))
        }
        
        if case .specific(let pageNumber)? = page, pageNumber < numberOfPages {
            keyCommands.append(UIKeyCommand.make(input: "]", modifierFlags: .command, action: #selector(loadNextPage), discoverabilityTitle: "Next Page"))
        }
        
        keyCommands.append(UIKeyCommand.make(input: "N", modifierFlags: .command, action: #selector(newReply), discoverabilityTitle: "New Reply"))
        
        return keyCommands
    }
}


extension PostsPageViewController: ChidoriDelegate {
    func didSelectAction(_ action: UIAction) {
        actionMappings[action.identifier]?(action)
    }
}
