//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import MobileCoreServices
import MRProgress
import PromiseKit

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
    private var observers: [NSKeyValueObservation] = []
    private(set) var page: ThreadPage?
    private var replyWorkspace: ReplyWorkspace?
    private var restoringState = false
    private var scrollToFractionAfterLoading: CGFloat?
    let thread: AwfulThread
    private var webViewDidLoadOnce = false

    #if targetEnvironment(UIKitForMac)
    weak var previewActionItemProvider: AnyObject?
    #else
    weak var previewActionItemProvider: PreviewActionItemProvider?
    #endif
    
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
            return Int(thread.filteredNumberOfPagesForAuthor(author: author))
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

                if (error as NSError).code == AwfulErrorCodes.archivesRequired {
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
            
            self?.dismiss(animated: true)
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
                
                UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
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
            
            if let author = self.author {
                actionVC.items = [copyURLItem, voteItem, bookmarkItem]
            } else {
                let ownPostsItem = IconActionItem(.ownPosts, block: {
                    let userKey = UserKey(userID: UserDefaults.standard.loggedInUserID!, username: UserDefaults.standard.loggedInUsername)
                    let user = User.objectForKey(objectKey: userKey, inManagedObjectContext: self.thread.managedObjectContext!) as! User
                    let postsVC = PostsPageViewController(thread: self.thread, author: user)
                    postsVC.restorationIdentifier = "Just your posts"
                    postsVC.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
                    self.navigationController?.pushViewController(postsVC, animated: true)
                })
                ownPostsItem.title = "Your Posts"

                actionVC.items = [copyURLItem, ownPostsItem, voteItem, bookmarkItem]
            }
            self.present(actionVC, animated: true, completion: nil)
            
            if let popover = actionVC.popoverPresentationController {
                popover.barButtonItem = sender
            }
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
                    postsView.refreshControl = PostsPageRefreshSpinnerView()
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

        // Sometimes a delay is handy when working on the refresh control (making sure it is working as expected without having the whole screen reload after 300ms).
        let delay = Tweaks.defaultStore.assign(Tweaks.posts.delayBeforePullForNext)
        let loadNext = { self.loadPage(nextPage, updatingCache: true, updatingLastReadPost: true) }
        if delay > 0 {
            after(seconds: delay).done(loadNext)
        } else {
            loadNext()
        }
    }
    
    @objc private func loadPreviousPage(_ sender: UIKeyCommand) {
        guard case .specific(let pageNumber)? = page, pageNumber > 1 else { return }
        loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func loadNextPage(_ sender: UIKeyCommand) {
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
    
    @objc private func scrollToTop(_ sender: UIKeyCommand) {
        postsView.renderView.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
    }
    
    @objc private func scrollUp(_ sender: UIKeyCommand) {
        let scrollView = postsView.renderView.scrollView
        scrollView.contentOffset.y = max(scrollView.contentOffset.y - 80, 0)
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
        
        postsView.renderView.interestingElements(at: sender.location(in: postsView.renderView)).done {
            _ = URLMenuPresenter.presentInterestingElements($0, from: self, renderView: self.postsView.renderView)
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
            UserDefaults.standard.loggedInUserCanSendPrivateMessages &&
            user.canReceivePrivateMessages &&
            user.userID != UserDefaults.standard.loggedInUserID
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
            sourceView.pointee = self.postsView.renderView
        }
        
        present(actionVC, animated: true, completion: nil)
    }
    
    private func didTapActionButtonWithRect(_ frame: CGRect, forPostAtIndex postIndex: Int) {
        assert(postIndex + hiddenPosts < posts.count, "post \(postIndex) beyond range (hiding \(hiddenPosts) posts")
        
        let post = posts[postIndex + hiddenPosts]
        let possessiveUsername: String
        if post.author?.username == UserDefaults.standard.loggedInUsername {
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
            
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ChromeActivity(url: url)])
            activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
                if completed && activityType == .copyToPasteboard {
                    UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
                }
            }
            self.present(activityVC, animated: false)
            
            if let popover = activityVC.popoverPresentationController {
                // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
                popover.sourceRect = frame
                popover.sourceView = self.postsView.renderView
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
                        
                        self.postsView.renderView.markReadUpToPost(identifiedBy: post.postID)
                        
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
                        guard let self = self else { return }
                        let replyWorkspace = ReplyWorkspace(post: post)
                        self.replyWorkspace = replyWorkspace
                        replyWorkspace.completion = self.replyCompletionBlock
                        self.present(replyWorkspace.viewController, animated: true)
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
                
                self.replyWorkspace?.quotePost(post, completion: { [weak self] error in
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

        if Tweaks.defaultStore.assign(Tweaks.posts.showCopyAsMarkdownAction) {
            items.append(IconActionItem(.copyTitle, title: "Copy Markdown", block: {
                UIPasteboard.general.setValue(post.gitHubFlavoredMarkdown, forPasteboardType: kUTTypePlainText as String)
            }))
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = items
        actionVC.title = "\(possessiveUsername) Post"
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            // TODO: previously this would eval some js on the webview to find the new location of the header after rotating, but that sync call on UIWebView is async on WKWebView, so ???
            sourceRect.pointee = frame
            sourceView.pointee = self.postsView.renderView
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

        postsView.themeDidChange(theme)
        
        if postsView.loadingView != nil {
            postsView.loadingView = LoadingView.loadingViewWithTheme(theme)
        }

        messageViewController?.themeDidChange()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /*
         Laying this screen out is a challenge: there are bars on the top and bottom, and between our deployment target and the latest SDK we span a few different schools of layout thought. Here's the plan:

         1. Turn off all UIKit magic automated everything. We'll handle all scroll view content insets and safe area insets ourselves.
         2. Set layout margins on `postsView` in lieu of the above. Layout margins are available on all iOS versions that Awful supports.

         Here is where we turn off the magic. In `viewDidLayoutSubviews` we update the layout margins.
         */
        extendedLayoutIncludesOpaqueBars = true
        if #available(iOS 11.0, *) {
            postsView.insetsLayoutMarginsFromSafeArea = false
            postsView.renderView.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        view.addSubview(postsView, constrainEdges: .all)

        let spacer: CGFloat = 12
        postsView.toolbarItems = [
            settingsItem, .flexibleSpace(),
            backItem, .fixedSpace(spacer), currentPageItem, .fixedSpace(spacer), forwardItem,
            .flexibleSpace(), actionsItem]

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnPostsView))
        longPress.delegate = self
        postsView.renderView.addGestureRecognizer(longPress)
        
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

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePostsViewLayoutMargins()
    }

    private func updatePostsViewLayoutMargins() {
        // See commentary in `viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
        if #available(iOS 11.0, *) {
            postsView.layoutMargins = view.safeAreaInsets
        } else {
            postsView.layoutMargins = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: bottomLayoutGuide.length, right: 0)
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
            if url.fragment == "awful-ignored", case .post(let postID) = route {
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

#if !targetEnvironment(UIKitForMac)
extension PostsPageViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        return previewActionItemProvider?.previewActionItems ?? []
    }
}
#endif

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
