//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import AwfulCore
import CoreData
import MRProgress
import PromiseKit
import TUSafariActivity

private let Log = Logger.get()

/// Shows a list of posts in a thread.
final class PostsPageViewController: ViewController {
    
    private var advertisementHTML: String?
    private let author: User?
    private var flagRequest: Cancellable?
    private var jumpToLastPost = false
    private var jumpToPostIDAfterLoading: String?
    private var messageViewController: MessageComposeViewController?
    private weak var networkOperation: Cancellable?
    private(set) var page: ThreadPage?
    weak var previewActionItemProvider: PreviewActionItemProvider?
    private var refreshControl: PostsPageRefreshControl?
    private var replyWorkspace: ReplyWorkspace?
    private var restoringState = false
    private var scrollToFractionAfterLoading: CGFloat?
    let thread: AwfulThread
    private var webViewDidLoadOnce = false
    
    private var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }
    
    private var loadingView: LoadingView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let loadingView = loadingView , isViewLoaded {
                view.addSubview(loadingView)
            }
        }
    }
    
    private lazy var postsView: PostsPageView = {
        let postsView = PostsPageView()
        
        postsView.topBar.parentForumButton.addTarget(self, action: #selector(goToParentForum), for: .primaryActionTriggered)
        
        postsView.topBar.previousPostsButton.addTarget(self, action: #selector(showHiddenSeenPosts), for: .primaryActionTriggered)
        postsView.topBar.previousPostsButton.isEnabled = hiddenPosts > 0
        
        postsView.topBar.scrollToBottomButton.addTarget(self, action: #selector(scrollToBottom as () -> Void), for: .primaryActionTriggered)
        
        let renderView = postsView.renderView
        
        renderView.delegate = self
        
        renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidRender.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidTapPostActionButton.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        renderView.registerMessage(FYADFlagRequest.self)
        
        return postsView
    }()
    
    private var renderView: RenderView {
        return postsView.renderView
    }
    
    private var scrollView: UIScrollView {
        return postsView.scrollView
    }
    
    private struct FYADFlagRequest: RenderViewMessage {
        static let messageName = "fyadFlagRequest"
        
        init?(_ message: WKScriptMessage) {
            assert(message.name == FYADFlagRequest.messageName)
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
        
        let spacerWidth: CGFloat = 12
        toolbarItems = [
            settingsItem,
            UIBarButtonItem.flexibleSpace(),
            backItem,
            UIBarButtonItem.fixedSpace(spacerWidth),
            currentPageItem,
            UIBarButtonItem.fixedSpace(spacerWidth),
            forwardItem,
            UIBarButtonItem.flexibleSpace(),
            actionsItem,
        ]
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
    }
    
    var posts: [Post] = []
    
    var numberOfPages: Int {
        if let author = author {
            return Int(thread.filteredNumberOfPagesForAuthor(author: author))
        } else {
            return Int(thread.numberOfPages)
        }
    }
    
    override var theme: Theme {
        guard let forum = thread.forum, !forum.forumID.isEmpty else { return Theme.currentTheme }
        return Theme.currentThemeForForum(forum: forum)
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
    func loadPage(_ newPage: ThreadPage, updatingCache: Bool, updatingLastReadPost updateLastReadPost: Bool) {
        flagRequest?.cancel()
        flagRequest = nil
        networkOperation?.cancel()
        networkOperation = nil
        
        // Clear the post or fractional offset to scroll to. It's assumed that whatever calls this will
        // take care of re-establishing where to scroll to after calling loadPage().
        jumpToPostIDAfterLoading = nil
        scrollToFractionAfterLoading = nil
        jumpToLastPost = false
        
        // SA: When filtering the thread by a single user, the "goto=lastpost" redirect ignores the user filter, so we'll do our best to guess.
        var newPage = newPage
        if let author = author, case .last? = page {
            newPage = .specific(Int(thread.filteredNumberOfPagesForAuthor(author: author)))
        }
        
        let reloadingSamePage = page == newPage
        page = newPage
        
        if posts.isEmpty || !reloadingSamePage {
            refreshControl?.endRefreshing()
            
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

        let (promise, cancellable) = ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: newPage, updateLastReadPost: updateLastReadPost)
        networkOperation = cancellable

        promise.done { [weak self] posts, firstUnreadPost, advertisementHTML in
            guard let sself = self else { return }

            // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
            guard sself.page == newPage else { return }

            if !posts.isEmpty {
                sself.posts = posts

                let anyPost = posts[0]
                if sself.author != nil {
                    sself.page = .specific(anyPost.singleUserPage)
                } else {
                    sself.page = .specific(anyPost.page)
                }
            }

            switch newPage {
            case .last where sself.posts.isEmpty,
                 .nextUnread where sself.posts.isEmpty:
                let pageCount = sself.numberOfPages > 0 ? "\(sself.numberOfPages)" : "?"
                sself.currentPageItem.title = "Page ? of \(pageCount)"

            case .last, .nextUnread, .specific:
                break
            }

            sself.configureUserActivityIfPossible()

            if sself.hiddenPosts == 0, let firstUnreadPost = firstUnreadPost, firstUnreadPost > 0 {
                sself.hiddenPosts = firstUnreadPost - 1
            }

            if reloadingSamePage || renderedCachedPosts {
                sself.scrollToFractionAfterLoading = sself.scrollView.fractionalContentOffset.y
            }

            sself.renderPosts()

            sself.updateUserInterface()

            if let lastPost = sself.posts.last, updateLastReadPost {
                if sself.thread.seenPosts < lastPost.threadIndex {
                    sself.thread.seenPosts = lastPost.threadIndex
                }
            }

            sself.refreshControl?.endRefreshing()
            }

            .catch { [weak self] error in
                guard let sself = self else { return }

                // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
                if sself.page != newPage { return }

                sself.clearLoadingMessage()

                if (error as NSError).code == AwfulErrorCodes.archivesRequired {
                    let alert = UIAlertController(title: "Archives Required", error: error)
                    sself.present(alert, animated: true)
                } else {
                    let offlineMode = (error as NSError).domain == NSURLErrorDomain && (error as NSError).code != NSURLErrorCancelled
                    if sself.posts.isEmpty || !offlineMode {
                        let alert = UIAlertController(title: "Could Not Load Page", error: error)
                        sself.present(alert, animated: true)
                    }
                }

                switch newPage {
                case .last where sself.posts.isEmpty,
                     .nextUnread where sself.posts.isEmpty:
                    let pageCount = sself.numberOfPages > 0 ? "\(sself.numberOfPages)" : "?"
                    sself.currentPageItem.title = "Page ? of \(pageCount)"

                case .last, .nextUnread, .specific:
                    break
                }
        }
    }
    
    /// Scroll the posts view so that a particular post is visible (if the post is on the current(ly loading) page).
    func scrollPostToVisible(_ post: Post) {
        let i = posts.index(of: post)
        if loadingView != nil || !webViewDidLoadOnce || i == nil {
            jumpToPostIDAfterLoading = post.postID
        } else {
            if let i = i , i < hiddenPosts {
                showHiddenSeenPosts()
            }
            
            renderView.jumpToPost(identifiedBy: post.postID)
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
        renderView.eraseDocument()
        
        webViewDidLoadOnce = false
        
        var context: [String: Any] = [:]
        
        context["stylesheet"] = (theme["postsViewCSS"] as String?) as Any
        
        if posts.count > hiddenPosts {
            let subset = posts[hiddenPosts...]
            context["posts"] = subset.map { PostViewModel($0) }
        }
        
        if let ad = advertisementHTML, !ad.isEmpty {
            context["advertisementHTML"] = ad
        }
        
        if context["posts"] != nil, case .specific(let pageNumber)? = page, pageNumber >= numberOfPages {
            context["endMessage"] = true
        }
        
        if let username = AwfulSettings.shared().username, !username.isEmpty {
            context["loggedInUsername"] = username
        }
        
        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.shared.stylesheet
        
        if !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID
        }
        
        if let forum = thread.forum, !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }

        let html: String
        do {
            html = try MustacheTemplate.render(.postsView, value: context)
        } catch {
            Log.e("could not render posts view HTML: \(error)")
            html = ""
        }
        
        renderView.render(html: html, baseURL: ForumsClient.shared.baseURL)
    }
    
    private lazy var composeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Reply to thread"
        item.actionBlock = { [weak self] (sender) in
            guard let strongSelf = self else { return }
            if strongSelf.replyWorkspace == nil {
                strongSelf.replyWorkspace = ReplyWorkspace(thread: strongSelf.thread)
                strongSelf.replyWorkspace?.completion = strongSelf.replyCompletionBlock
            }
            strongSelf.present(strongSelf.replyWorkspace!.viewController, animated: true, completion: nil)
        }
        return item
    }()
    
    @objc private func newReply(_ sender: UIKeyCommand) {
        if replyWorkspace == nil {
            replyWorkspace = ReplyWorkspace(thread: thread)
            replyWorkspace?.completion = replyCompletionBlock
        }
        present(replyWorkspace!.viewController, animated: true, completion: nil)
    }
    
    private var replyCompletionBlock: (_ saveDraft: Bool, _ didSucceed: Bool) -> Void {
        return { [weak self] (saveDraft, didSucceed) in
            if !saveDraft {
                self?.replyWorkspace = nil
            }
            
            if didSucceed {
                self?.loadPage(.nextUnread, updatingCache: true, updatingLastReadPost: true)
            }
            
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private lazy var settingsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "page-settings"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Settings"
        item.actionBlock = { [unowned self] (sender) in
            guard let forum = self.thread.forum else { return }
            let settings = PostsPageSettingsViewController(forum: forum)
            settings.selectedTheme = self.theme
            self.present(settings, animated: true, completion: nil)
            
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
            self.loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    private lazy var currentPageItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        item.possibleTitles = ["2345 / 2345"]
        item.accessibilityHint = "Opens page picker"
        item.actionBlock = { [unowned self] (sender) in
            guard self.loadingView == nil else { return }
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
            self.loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    private lazy var actionsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "action"), style: .plain, target: nil, action: nil)
        item.actionBlock = { [unowned self] (sender) in
            let actionVC = InAppActionViewController()
            actionVC.title = self.title
            
            let copyURLItem = IconActionItem(.copyURL, block: { 
                let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
                var queryItems = [
                    URLQueryItem(name: "threadid", value: self.thread.threadID),
                    URLQueryItem(name: "perpage", value: "40"),
                ]
                if case .specific(let pageNumber)? = self.page, pageNumber > 1 {
                    queryItems.append(URLQueryItem(name: "pagenumber", value: "\(pageNumber)"))
                }
                components.queryItems = queryItems
                let url = components.url!
                
                AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                UIPasteboard.general.coercedURL = url
            })
            copyURLItem.title = "Copy URL"
            
            let voteItem = IconActionItem(.vote, block: { [unowned self] in
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
                
                if let popover = actionSheet.popoverPresentationController {
                    popover.barButtonItem = sender
                }
            })
            
            let bookmarkType: IconAction = self.thread.bookmarked ? .removeBookmark : .addBookmark
            let bookmarkItem = IconActionItem(bookmarkType, block: {
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
            })
            
            actionVC.items = [copyURLItem, voteItem, bookmarkItem]
            self.present(actionVC, animated: true, completion: nil)
            
            if let popover = actionVC.popoverPresentationController {
                popover.barButtonItem = sender
            }
        }
        return item
    }()
    
    @objc private func settingsDidChange(_ notification: NSNotification) {
        guard isViewLoaded else { return }
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? NSString else { return }
        
        switch key {
        case AwfulSettingsKeys.showAvatars.takeUnretainedValue():
            renderView.setShowAvatars(AwfulSettings.shared().showAvatars)
            
        case AwfulSettingsKeys.fontScale.takeUnretainedValue():
            renderView.setFontScale(AwfulSettings.shared().fontScale)
            
        case AwfulSettingsKeys.showImages.takeUnretainedValue() where AwfulSettings.shared().showImages:
            renderView.loadLinkifiedImages()
        
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() where visible:
            configureUserActivityIfPossible()
        
        case AwfulSettingsKeys.embedTweets.takeUnretainedValue() where AwfulSettings.shared().embedTweets:
            renderView.embedTweets()
        
        default:
            break
        }
    }
    
    @objc private func externalStylesheetDidUpdate(_ rawNotification: Notification) {
        guard let notification = PostsViewExternalStylesheetLoader.DidUpdateNotification(rawNotification) else {
            return Log.e("got an unexpected or invalid notification: \(rawNotification)")
        }
        
        renderView.setExternalStylesheet(notification.stylesheet)
    }
    
    private func refetchPosts() {
        guard case .specific(let pageNumber)? = page else {
            posts = []
            return
        }
        
        let request = NSFetchRequest<Post>(entityName: Post.entityName())
        
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
        title = (thread.title as NSString?)?.stringByCollapsingWhitespace
        
        if page == .last || page == .nextUnread || posts.isEmpty {
            showLoadingView()
        }
        
        postsView.topBar.scrollToBottomButton.isEnabled = !posts.isEmpty
        postsView.topBar.previousPostsButton.isEnabled = hiddenPosts > 0

        if case .specific(let pageNumber)? = page, numberOfPages > pageNumber {
            if !(refreshControl?.contentView is PostsPageRefreshArrowView) {
                refreshControl?.contentView = PostsPageRefreshArrowView()
            }
        } else {
            if !(refreshControl?.contentView is PostsPageRefreshSpinnerView) {
                refreshControl?.contentView = PostsPageRefreshSpinnerView()
            }
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
        guard loadingView == nil else { return }
        loadingView = LoadingView.loadingViewWithTheme(theme)
    }
    
    private func clearLoadingMessage() {
        loadingView = nil
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
    
    @objc private func scrollToBottom() {
        scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 1, width: 1, height: 1), animated: true)
    }
    
    @objc private func loadPreviousPage(_ sender: UIKeyCommand) {
        guard case .specific(let pageNumber)? = page, pageNumber > 1 else { return }
        loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func loadNextPage(_ sender: UIKeyCommand) {
        guard case .specific(let pageNumber)? = page else { return }
        loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func goToParentForum() {
        guard let forum = thread.forum else { return }
        AppDelegate.instance.open(route: .forum(id: forum.forumID))
    }
    
    @objc private func showHiddenSeenPosts() {
        let end = hiddenPosts
        hiddenPosts = 0
        
        let html = (0..<end).map(renderedPostAtIndex).joined(separator: "\n")
        renderView.prependPostHTML(html)
    }
    
    @objc private func scrollToBottom(_ sender: UIKeyCommand) {
        scrollToBottom()
    }
    
    @objc private func scrollToTop(_ sender: UIKeyCommand) {
        scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
    }
    
    @objc private func scrollUp(_ sender: UIKeyCommand) {
        scrollView.contentOffset.y = max(scrollView.contentOffset.y - 80, 0)
    }
    
    @objc private func scrollDown(_ sender: UIKeyCommand) {
        let proposedOffset = scrollView.contentOffset.y + 80
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            let newOffset = CGPoint(x: scrollView.contentOffset.x, y: proposedOffset)
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }
    
    @objc private func pageUp(_ sender: UIKeyCommand) {
        let proposedOffset = scrollView.contentOffset.y - (scrollView.bounds.height - 80)
        let newOffset = CGPoint(x: scrollView.contentOffset.x, y: max(proposedOffset, 0))
        scrollView.setContentOffset(newOffset, animated: true)
    }
    
    @objc private func pageDown(_ sender: UIKeyCommand) {
        let proposedOffset = scrollView.contentOffset.y + (scrollView.bounds.height - 80)
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: proposedOffset), animated: true)
        }
    }
    
    @objc private func didLongPressOnPostsView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        renderView.interestingElements(at: sender.location(in: renderView)).done {
            _ = URLMenuPresenter.presentInterestingElements($0, from: self, renderView: self.renderView)
        }
    }
    
    private func renderedPostAtIndex(_ i: Int) -> String {
        let viewModel = PostViewModel(posts[i])
        do {
            return try MustacheTemplate.render(.post, value: viewModel)
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
                    let sself = self,
                    let i = sself.posts.index(of: post)
                    else { return }
                
                sself.renderView.replacePostHTML(sself.renderedPostAtIndex(i), at: i - sself.hiddenPosts)
            }
            .catch { [weak self] error in
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
        }
    }
    
    private func didTapUserHeaderWithRect(_ frame: CGRect, forPostAtIndex postIndex: Int) {
        let post = posts[postIndex + hiddenPosts]
        guard let user = post.author else { return }
        let actionVC = InAppActionViewController()
        var items: [IconActionItem] = []
        
        items.append(IconActionItem(.userProfile, block: {
            let profileVC = ProfileViewController(user: user)
            self.present(profileVC.enclosingNavigationController, animated: true, completion: nil)
        }))
        
        if author == nil {
            items.append(IconActionItem(.singleUsersPosts, block: {
                let postsVC = PostsPageViewController(thread: self.thread, author: user)
                postsVC.restorationIdentifier = "Just their posts"
                postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
                self.navigationController?.pushViewController(postsVC, animated: true)
            }))
        }
        
        if
            AwfulSettings.shared().canSendPrivateMessages &&
            user.canReceivePrivateMessages &&
            user.userID != AwfulSettings.shared().userID
        {
            items.append(IconActionItem(.sendPrivateMessage, block: {
                let messageVC = MessageComposeViewController(recipient: user)
                self.messageViewController = messageVC
                messageVC.delegate = self
                messageVC.restorationIdentifier = "New PM from posts view"
                self.present(messageVC.enclosingNavigationController, animated: true, completion: nil)
            }))
        }
        
        items.append(IconActionItem(.rapSheet, block: {
            let rapSheetVC = RapSheetViewController(user: user)
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.present(rapSheetVC.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(rapSheetVC, animated: true)
            }
        }))
        
        if let username = user.username {
            let ignoreAction: IconAction
            let ignoreBlock: (_ username: String) -> Promise<Void>
            if post.ignored {
                ignoreAction = .unignoreUser
                ignoreBlock = ForumsClient.shared.removeUserFromIgnoreList
            }
            else {
                ignoreAction = .ignoreUser
                ignoreBlock = ForumsClient.shared.addUserToIgnoreList
            }
            items.append(IconActionItem(ignoreAction, block: {
                let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Updating Ignore List", mode: .indeterminate, animated: true)
                overlay?.tintColor = self.theme["tintColor"]
                
                ignoreBlock(username)
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
            }))
        }
        
        actionVC.items = items
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
            sourceRect.pointee = frame
            sourceView.pointee = self.renderView
        }
        
        present(actionVC, animated: true, completion: nil)
    }
    
    private func didTapActionButtonWithRect(_ frame: CGRect, forPostAtIndex postIndex: Int) {
        assert(postIndex + hiddenPosts < posts.count, "post \(postIndex) beyond range (hiding \(hiddenPosts) posts")
        
        let post = posts[postIndex + hiddenPosts]
        let possessiveUsername: String
        if post.author?.username == AwfulSettings.shared().username {
            possessiveUsername = "Your"
        } else {
            possessiveUsername = "\(post.author?.username ?? "")'s"
        }
        
        var items: [IconActionItem] = []
        
        let shareItem = IconActionItem(.copyURL, block: {
            let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
            var queryItems = [
                URLQueryItem(name: "threadid", value: self.thread.threadID),
                URLQueryItem(name: "perpage", value: "40"),
            ]
            if case .specific(let pageNumber)? = self.page, pageNumber > 1 {
                queryItems.append(URLQueryItem(name: "pagenumber", value: "\(pageNumber)"))
            }
            components.queryItems = queryItems
            components.fragment = "post\(post.postID)"
            let url = components.url!
            
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
            activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
                if completed && activityType == .copyToPasteboard {
                    AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                }
            }
            self.present(activityVC, animated: false)
            
            if let popover = activityVC.popoverPresentationController {
                // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
                popover.sourceRect = frame
                popover.sourceView = self.scrollView
            }
        })
        shareItem.title = "Share URL"
        items.append(shareItem)
        
        if author == nil {
            items.append(IconActionItem(.markReadUpToHere, block: {
                ForumsClient.shared.markThreadAsReadUpTo(post)
                    .done { [weak self] in
                        post.thread?.seenPosts = post.threadIndex

                        guard let self = self else { return }
                        
                        self.renderView.markReadUpToPost(identifiedBy: post.postID)
                        
                        let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: LocalizedString("posts-page.marked-read"), mode: .checkmark, animated: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            overlay?.dismiss(true)
                        }
                    }
                    .catch { [weak self] error in
                        guard let self = self else { return }
                        
                        let alert = UIAlertController(title: LocalizedString("posts-page.error.could-not-mark-read"), error: error)
                        self.present(alert, animated: true)
                }
            }))
        }
        
        if post.editable {
            items.append(IconActionItem(.editPost, block: {
                ForumsClient.shared.findBBcodeContents(of: post)
                    .done { [weak self] text in
                        guard let sself = self else { return }
                        let replyWorkspace = ReplyWorkspace(post: post)
                        sself.replyWorkspace = replyWorkspace
                        replyWorkspace.completion = sself.replyCompletionBlock
                        sself.present(replyWorkspace.viewController, animated: true)
                    }
                    .catch { [weak self] error in
                        let alert = UIAlertController(title: "Could Not Edit Post", error: error)
                        self?.present(alert, animated: true)
                }
            }))
        }
        
        if !thread.closed {
            items.append(IconActionItem(.quotePost, block: {
                if self.replyWorkspace == nil {
                    self.replyWorkspace = ReplyWorkspace(thread: self.thread)
                    self.replyWorkspace?.completion = self.replyCompletionBlock
                }
                
                self.replyWorkspace?.quotePost(post, completion: { [weak self] (error) in
                    if let error = error {
                        let alert = UIAlertController(networkError: error)
                        self?.present(alert, animated: true, completion: nil)
                        return
                    }
                    
                    guard let vc = self?.replyWorkspace?.viewController else { return }
                    self?.present(vc, animated: true, completion: nil)
                })
            }))
        }
        
        items.append(IconActionItem(.reportPost, block: {
            let reportVC = ReportPostViewController(post: post)
            self.present(reportVC.enclosingNavigationController, animated: true, completion: nil)
        }))
        
        if author != nil {
            items.append(IconActionItem(.showInThread, block: {
                // This will add the thread to the navigation stack, giving us thread->author->thread.
                AppDelegate.instance.open(route: .post(id: post.postID))
            }))
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = items
        actionVC.title = "\(possessiveUsername) Post"
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
            sourceRect.pointee = frame
            sourceView.pointee = self.renderView
        }
        present(actionVC, animated: true)
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
                self.renderView.setFYADFlag($0)
            }
            .catch { error in
                Log.w("could not fetch FYAD flag: \(error)")
                self.renderView.setFYADFlag(nil)
        }
    }
    
    private func configureUserActivityIfPossible() {
        guard case .specific? = page, AwfulSettings.shared().handoffEnabled else {
            userActivity = nil
            return
        }
        
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.browsingPosts)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        guard let page = page, case .specific = page else { return }

        activity.route = {
            if let author = author {
                return .threadPageSingleUser(threadID: thread.threadID, userID: author.userID, page: page)
            } else {
                return .threadPage(threadID: thread.threadID, page: page)
            }
        }()
        activity.title = thread.title

        Log.d("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        scrollView.indicatorStyle = theme.scrollIndicatorStyle
        
        renderView.setThemeStylesheet(theme["postsViewCSS"] ?? "")
        
        if loadingView != nil {
            loadingView = LoadingView.loadingViewWithTheme(theme)
        }
        
        let topBar = postsView.topBar
        topBar.backgroundColor = theme["postsTopBarBackgroundColor"]
        for button in [topBar.parentForumButton, topBar.previousPostsButton, topBar.scrollToBottomButton] {
            button.setTitleColor(theme["postsTopBarTextColor"], for: .normal)
            button.setTitleColor(theme["postsTopBarTextColor"]?.withAlphaComponent(0.5), for: .disabled)
            button.backgroundColor = theme["postsTopBarBackgroundColor"]
        }
        
        messageViewController?.themeDidChange()
        
        refreshControl?.tintColor = theme["postsPullForNextColor"]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        postsView.frame = CGRect(origin: .zero, size: view.bounds.size)
        postsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(postsView)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnPostsView))
        longPress.delegate = self
        renderView.addGestureRecognizer(longPress)
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalStylesheetDidUpdate), name: PostsViewExternalStylesheetLoader.DidUpdateNotification.name, object: PostsViewExternalStylesheetLoader.shared)
        
        if AwfulSettings.shared().pullForNext {
            refreshControl = PostsPageRefreshControl(scrollView: scrollView, contentView: PostsPageRefreshSpinnerView())
            refreshControl?.handler = { [weak self] in
                self?.loadNextPageOrRefresh()
            }
            refreshControl?.tintColor = theme["postsPullForNextColor"]
        }
        
        kvoController.observe(scrollView, keyPath: #keyPath(UIScrollView.contentSize), options: .initial) { [weak self] observee, change in
            self?.refreshControl?.scrollViewContentSizeDidChange()
        }
        
        if let loadingView = loadingView {
            view.addSubview(loadingView)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUserActivityIfPossible()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }

    override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        guard parent != nil || previewActionItemProvider == nil else {
            // RDAR: 36754995 presenting an alert in a peek view controller often results in a screen-covering blurred view that eats all touches. Peek view controllers seem to have no parent, and as a double-check we'll see if we seem to be configured with a preview action item provider (which should only happen when we're peeking), then we'll just swallow any attempted presentation.
            Log.w("ignoring attempt to present \(viewController) as we're pretty sure we're part of an ongoing peek 3D Touch action, and that's a bad time to present something")
            return
        }

        super.present(viewController, animated: animated, completion: completion)
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
        coder.encode(Float(scrollView.fractionalContentOffset.y), forKey: Keys.scrolledFractionOfContent)
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
        dismiss(animated: true, completion: nil)
    }
}

extension PostsPageViewController: RenderViewDelegate {
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case is RenderView.BuiltInMessage.DidRender:
            if AwfulSettings.shared().embedTweets {
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
                renderView.jumpToPost(identifiedBy: postID)
            } else if let newFractionalOffset = scrollToFractionAfterLoading {
                var fractionalOffset = scrollView.fractionalContentOffset
                fractionalOffset.y = newFractionalOffset
                renderView.scrollToFractionalOffset(fractionalOffset)
            }
            
            clearLoadingMessage()
            
        case let message as RenderView.BuiltInMessage.DidTapAuthorHeader:
            didTapUserHeaderWithRect(message.frame, forPostAtIndex: message.postIndex)
            
        case let message as RenderView.BuiltInMessage.DidTapPostActionButton:
            didTapActionButtonWithRect(message.frame, forPostAtIndex: message.postIndex)
            
        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            if let postID = jumpToPostIDAfterLoading {
                renderView.jumpToPost(identifiedBy: postID)
            } else if let fraction = scrollToFractionAfterLoading, fraction > 0 {
                var offset = scrollView.fractionalContentOffset
                offset.y = fraction
                renderView.scrollToFractionalOffset(offset)
            }
            
        case is FYADFlagRequest:
            fetchNewFlag()
            
        default:
            Log.w("ignoring unexpected JavaScript message: \(type(of: message).messageName)")
        }
    }
    
    func didTapLink(to url: URL, in view: RenderView) {
        if let route = try? AwfulRoute(url) {
            if url.fragment == "awful-ignored", case .post(let postID) = route {
                if let i = posts.index(where: { $0.postID == postID }) {
                    readIgnoredPostAtIndex(i)
                }
            } else {
                AppDelegate.instance.open(route: route)
            }
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.openURL(url)
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
        let context = AppDelegate.instance.managedObjectContext
        guard let
            threadKey = coder.decodeObject(forKey: Keys.threadKey) as? ThreadKey,
            let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: context) as? AwfulThread
            else { return nil }
        let userKey = coder.decodeObject(forKey: Keys.authorUserKey) as? UserKey
        let author: User?
        if let userKey = userKey {
            author = User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User
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
    override var previewActionItems: [UIPreviewActionItem] {
        return previewActionItemProvider?.previewActionItems ?? []
    }
}

extension PostsPageViewController {
    override var keyCommands: [UIKeyCommand]? {
        var keyCommands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(scrollUp), discoverabilityTitle: "Up"),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(scrollDown), discoverabilityTitle: "Down"),
            UIKeyCommand(input: " ", modifierFlags: .shift, action: #selector(pageUp), discoverabilityTitle: "Page Up"),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(pageDown), discoverabilityTitle: "Page Down"),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: .command, action: #selector(scrollToTop), discoverabilityTitle: "Scroll to Top"),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: .command, action: #selector(scrollToBottom(_:)), discoverabilityTitle: "Scroll to Bottom"),
        ]
        
        if case .specific(let pageNumber)? = page, pageNumber > 1 {
            keyCommands.append(UIKeyCommand(input: "[", modifierFlags: .command, action: #selector(loadPreviousPage), discoverabilityTitle: "Previous Page"))
        }
        
        if case .specific(let pageNumber)? = page, pageNumber < numberOfPages {
            keyCommands.append(UIKeyCommand(input: "]", modifierFlags: .command, action: #selector(loadNextPage), discoverabilityTitle: "Next Page"))
        }
        
        keyCommands.append(UIKeyCommand(input: "N", modifierFlags: .command, action: #selector(newReply), discoverabilityTitle: "New Reply"))
        
        return keyCommands
    }
}
