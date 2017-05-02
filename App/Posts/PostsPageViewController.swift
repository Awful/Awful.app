//  PostsPageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ARChromeActivity
import AwfulCore
import GRMustache
import MRProgress
import TUSafariActivity
import WebViewJavascriptBridge

/// Shows a list of posts in a thread.
final class PostsPageViewController: ViewController {
    let thread: AwfulThread
    fileprivate let author: User?
    fileprivate(set) var page = 0
    fileprivate var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }
    fileprivate var webViewDidLoadOnce = false
    fileprivate var advertisementHTML: String?
    fileprivate weak var networkOperation: Cancellable?
    fileprivate var refreshControl: PostsPageRefreshControl?
    fileprivate var loadingView: LoadingView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let loadingView = loadingView , isViewLoaded {
                view.addSubview(loadingView)
            }
        }
    }
    fileprivate var webViewNetworkActivityIndicatorManager: WebViewNetworkActivityIndicatorManager?
    fileprivate var webViewJavascriptBridge: WebViewJavascriptBridge?
    fileprivate var replyWorkspace: ReplyWorkspace?
    fileprivate var messageViewController: MessageComposeViewController?
    fileprivate var jumpToPostIDAfterLoading: String?
    fileprivate var jumpToLastPost = false
    fileprivate var scrollToFractionAfterLoading: CGFloat?
    fileprivate var restoringState = false
    weak var previewActionItemProvider: PreviewActionItemProvider?
    
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        guard let forum = thread.forum , !forum.forumID.isEmpty else { return Theme.currentTheme }
        return Theme.currentThemeForForum(forum: forum)
    }
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    fileprivate var postsView: PostsView {
        return view as! PostsView
    }
    
    fileprivate var webView: UIWebView {
        return postsView.webView
    }
    
    /**
        Changes the page.
     
        - parameter page: The page to load. Values of AwfulThreadPage are allowed here too (but it's typed NSInteger for Swift compatibility).
        - parameter updateCache: Whether to fetch posts from the client, or simply render any posts that are cached.
        - parameter updateLastReadPost: Whether to advance the "last-read post" marker on the Forums.
     */
    func loadPage(_ rawPage: Int, updatingCache: Bool, updatingLastReadPost updateLastReadPost: Bool) {
        networkOperation?.cancel()
        networkOperation = nil
        
        // Clear the post or fractional offset to scroll to. It's assumed that whatever calls this will
        // take care of re-establishing where to scroll to after calling loadPage().
        jumpToPostIDAfterLoading = nil
        scrollToFractionAfterLoading = nil
        jumpToLastPost = false
        
        // SA: When filtering the thread by a single user, the "goto=lastpost" redirect ignores the user filter, so we'll do our best to guess.
        var rawPage = rawPage
        if let
            author = author,
            let page = AwfulThreadPage(rawValue: rawPage)
            , page == .last
        {
            rawPage = Int(thread.filteredNumberOfPagesForAuthor(author: author))
            if rawPage == 0 {
                rawPage = 1
            }
        }
        
        let reloadingSamePage = page == rawPage
        page = rawPage
        
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

        let (promise, cancellable) = ForumsClient.shared.listPosts(in: thread, writtenBy: author, page: rawPage, updateLastReadPost: updateLastReadPost)
        networkOperation = cancellable

        promise.then { [weak self] (posts, firstUnreadPost, advertisementHTML) -> Void in
            guard let sself = self else { return }

            // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
            guard sself.page == rawPage else { return }

            if !posts.isEmpty {
                sself.posts = posts

                let anyPost = posts[0]
                if sself.author != nil {
                    sself.page = anyPost.singleUserPage
                } else {
                    sself.page = anyPost.page
                }
            }

            if sself.posts.isEmpty && rawPage < 0 {
                let pageCount = sself.numberOfPages > 0 ? "\(sself.numberOfPages)" : "?"
                sself.currentPageItem.title = "Page ? of \(pageCount)"
            }

            sself.configureUserActivityIfPossible()

            if sself.hiddenPosts == 0, let firstUnreadPost = firstUnreadPost, firstUnreadPost > 0 {
                sself.hiddenPosts = firstUnreadPost - 1
            }

            if reloadingSamePage || renderedCachedPosts {
                sself.scrollToFractionAfterLoading = sself.webView.fractionalContentOffset
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

            .catch { [weak self] (error) -> Void in
                guard let sself = self else { return }

                // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
                if sself.page != rawPage { return }

                sself.clearLoadingMessage()

                if (error as NSError).code == AwfulErrorCodes.archivesRequired {
                    let alert = UIAlertController(title: "Archives Required", error: error)
                    sself.present(alert, animated: true, completion: nil)
                } else {
                    let offlineMode = !ForumsClient.shared.isReachable && (error as NSError).domain == NSURLErrorDomain
                    if sself.posts.isEmpty || !offlineMode {
                        let alert = UIAlertController(title: "Could Not Load Page", error: error)
                        sself.present(alert, animated: true, completion: nil)
                    }
                }

                if sself.posts.isEmpty && rawPage < 0 {
                    let pageCount = sself.numberOfPages > 0 ? "\(sself.numberOfPages)" : "?"
                    sself.currentPageItem.title = "Page ? of \(pageCount)"
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
            
            webViewJavascriptBridge?.callHandler("jumpToPostWithID", data: post.postID)
        }
    }
    
    func goToLastPost() {
        loadPage(AwfulThreadPage.last.rawValue, updatingCache: true, updatingLastReadPost: true)
        jumpToLastPost = true
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    fileprivate func renderPosts() {
        loadBlankPage()
        
        webViewDidLoadOnce = false
        
        var context: [String: AnyObject] = [:]
        
        var error: NSError? = nil
        if let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "posts-view.js"], &error) {
            context["script"] = script as AnyObject?
        } else {
            print("\(#function) error loading scripts: \(error!)")
            return
        }
        
        context["version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String as NSString
        context["userInterfaceIdiom"] = (UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone") as NSString
        context["stylesheet"] = (theme["postsViewCSS"] as String?)! as NSString
        
        if posts.count > hiddenPosts {
            let subset = posts[hiddenPosts ..< posts.endIndex]
            context["posts"] = subset.map(PostViewModel.init) as NSArray
        }
        
        if let ad = advertisementHTML , !ad.isEmpty {
            context["advertisementHTML"] = ad as AnyObject?
        }
        
        if context["posts"] != nil && page > 0 && page >= numberOfPages {
            context["endMessage"] = true as AnyObject?
        }
        
        let fontScalePercentage = AwfulSettings.shared().fontScale
        if fontScalePercentage != 100 {
            context["fontScalePercentage"] = fontScalePercentage as AnyObject?
        }
        
        if let username = AwfulSettings.shared().username , !username.isEmpty {
            context["loggedInUsername"] = username as AnyObject?
        }
        
        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.sharedLoader.stylesheet as AnyObject?
        
        if !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID as AnyObject?
        }
        
        if let forum = thread.forum , !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID as AnyObject?
        }
        
        do {
            let html = try GRMustacheTemplate.renderObject(context, fromResource: "PostsView", bundle: nil)
            webView.loadHTMLString(html, baseURL: ForumsClient.shared.baseURL)
        } catch {
            print("\(#function) error loading posts view HTML: \(error)")
        }
    }
    
    fileprivate func loadBlankPage() {
        let request = NSURLRequest(url: NSURL(string: "about:blank")! as URL)
        webView.loadRequest(request as URLRequest)
    }
    
    fileprivate lazy var composeItem: UIBarButtonItem = {
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
    
    @objc fileprivate func newReply(_ sender: UIKeyCommand) {
        if replyWorkspace == nil {
            replyWorkspace = ReplyWorkspace(thread: thread)
            replyWorkspace?.completion = replyCompletionBlock
        }
        present(replyWorkspace!.viewController, animated: true, completion: nil)
    }
    
    fileprivate var replyCompletionBlock: (_ saveDraft: Bool, _ didSucceed: Bool) -> Void {
        return { [weak self] (saveDraft, didSucceed) in
            if !saveDraft {
                self?.replyWorkspace = nil
            }
            
            if didSucceed {
                self?.loadPage(AwfulThreadPage.nextUnread.rawValue, updatingCache: true, updatingLastReadPost: true)
            }
            
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    fileprivate lazy var settingsItem: UIBarButtonItem = {
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
    
    fileprivate lazy var backItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "arrowleft"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Previous page"
        item.actionBlock = { [unowned self] (sender) in
            guard self.page > 1 else { return }
            self.loadPage(self.page - 1, updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    fileprivate lazy var currentPageItem: UIBarButtonItem = {
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
    
    fileprivate lazy var forwardItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "arrowright"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Next page"
        item.actionBlock = { [unowned self] (sender) in
            guard self.page < self.numberOfPages && self.page > 0 else { return }
            self.loadPage(self.page + 1, updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    fileprivate lazy var actionsItem: UIBarButtonItem = {
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
                if self.page > 1 {
                    queryItems.append(URLQueryItem(name: "pagenumber", value: "\(self.page)"))
                }
                components.queryItems = queryItems
                let url = components.url!
                
                AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                UIPasteboard.general.awful_URL = url
            })
            copyURLItem.title = "Copy URL"
            
            let voteItem = IconActionItem(.vote, block: { [unowned self] in
                let actionSheet = UIAlertController.actionSheet()
                for i in stride(from: 5, to: 0, by: -1) {
                    actionSheet.addActionWithTitle("\(i)", handler: {
                        let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Voting \(i)", mode: .indeterminate, animated: true)
                        overlay?.tintColor = self.theme["tintColor"]
                        
                        _ = ForumsClient.shared.rate(self.thread, as: i)
                            .then { () -> Void in
                                overlay?.mode = .checkmark

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    overlay?.dismiss(true)
                                }
                            }
                            .catch { [weak self] (error) -> Void in

                                overlay?.dismiss(false)

                                let alert = UIAlertController(title: "Vote Failed", error: error)
                                self?.present(alert, animated: true, completion: nil)
                        }
                    })
                }
                actionSheet.addCancelActionWithHandler(nil)
                self.present(actionSheet, animated: false, completion: nil)
                
                if let popover = actionSheet.popoverPresentationController {
                    popover.barButtonItem = sender
                }
            })
            
            let bookmarkType: IconAction = self.thread.bookmarked ? .removeBookmark : .addBookmark
            let bookmarkItem = IconActionItem(bookmarkType, block: {
                _ = ForumsClient.shared.setThread(self.thread, isBookmarked: !self.thread.bookmarked)
                    .then { [weak self] () -> Void in
                        guard let strongSelf = self else { return }

                        let status = strongSelf.thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                        let overlay = MRProgressOverlayView.showOverlayAdded(to: strongSelf.view, title: status, mode: .checkmark, animated: true)
                        overlay?.tintColor = strongSelf.theme["tintColor"]
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            overlay?.dismiss(true)
                        }
                    }
                    .catch { (error) -> Void in
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
    
    @objc fileprivate func settingsDidChange(_ notification: NSNotification) {
        guard isViewLoaded else { return }
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        
        switch key {
        case AwfulSettingsKeys.showAvatars.takeUnretainedValue() as String as String:
            webViewJavascriptBridge?.callHandler("showAvatars", data: AwfulSettings.shared().showAvatars)

        case AwfulSettingsKeys.username.takeUnretainedValue() as String as String:
            webViewJavascriptBridge?.callHandler("highlightMentionUsername", data: AwfulSettings.shared().username)
            
        case AwfulSettingsKeys.fontScale.takeUnretainedValue() as String as String:
            webViewJavascriptBridge?.callHandler("fontScale", data: AwfulSettings.shared().fontScale)
            
        case AwfulSettingsKeys.showImages.takeUnretainedValue() as String as String where AwfulSettings.shared().showImages:
            webViewJavascriptBridge?.callHandler("loadLinkifiedImages")
        
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() as String as String where visible:
            configureUserActivityIfPossible()
        
        case AwfulSettingsKeys.embedTweets.takeUnretainedValue() as String as String where AwfulSettings.shared().embedTweets:
            webViewJavascriptBridge?.callHandler("embedTweets")
        
        default:
            break
        }
    }
    
    @objc fileprivate func externalStylesheetDidUpdate(_ notification: NSNotification) {
        webViewJavascriptBridge?.callHandler("changeExternalStylesheet", data: notification.object)
    }
    
    fileprivate func refetchPosts() {
        guard page >= 1 else {
            posts = []
            return
        }
        
        let request = NSFetchRequest<Post>(entityName: Post.entityName())
        
        let indexKey = author == nil ? "threadIndex" : "filteredThreadIndex"
        let predicate = NSPredicate(format: "thread = %@ AND %d <= %K AND %K <= %d", thread, (page - 1) * 40 + 1, indexKey, indexKey, page * 40)
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
    
    fileprivate func updateUserInterface() {
        title = (thread.title as NSString?)?.stringByCollapsingWhitespace
        
        if page == AwfulThreadPage.last.rawValue || page == AwfulThreadPage.nextUnread.rawValue || posts.isEmpty {
            showLoadingView()
        } else {
            clearLoadingMessage()
        }
        
        postsView.topBar.scrollToBottomButton.isEnabled = !posts.isEmpty
        postsView.topBar.previousPostsButton.isEnabled = hiddenPosts > 0
        
        if numberOfPages > page {
            if !(refreshControl?.contentView is PostsPageRefreshArrowView) {
                refreshControl?.contentView = PostsPageRefreshArrowView()
            }
        } else {
            if !(refreshControl?.contentView is PostsPageRefreshSpinnerView) {
                refreshControl?.contentView = PostsPageRefreshSpinnerView()
            }
        }
        
        backItem.isEnabled = page > 1
        
        if page > 0 && numberOfPages > 0 {
            currentPageItem.title = "\(page) / \(numberOfPages)"
            currentPageItem.accessibilityLabel = "Page \(page) of \(numberOfPages)"
        } else {
            currentPageItem.title = ""
            currentPageItem.accessibilityLabel = nil
        }
        
        forwardItem.isEnabled = page > 0 && page < numberOfPages
        
        composeItem.isEnabled = !thread.closed
    }
    
    fileprivate func showLoadingView() {
        guard loadingView == nil else { return }
        loadingView = LoadingView.loadingViewWithTheme(theme)
    }
    
    fileprivate func clearLoadingMessage() {
        loadingView = nil
    }
    
    fileprivate func loadNextPageOrRefresh() {
        let nextPage: Int
        
        // There's surprising sublety in figuring out what "next page" means.
        if posts.count < 40 {
            // When we're showing a partial page, just fill in the rest by reloading the current page.
            nextPage = page
        } else if page == numberOfPages {
            // When we've got a full page but we're not sure there's another, just reload. The next page arrow will light up if we've found more pages. This is pretty subtle and not at all ideal. (Though doing something like going to the next unread page is even more confusing!)
            nextPage = page
        } else {
            // Otherwise we know there's another page, so fire away.
            nextPage = page + 1
        }
        
        loadPage(nextPage, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc fileprivate func scrollToBottom() {
        let scrollView = webView.scrollView
        scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 1, width: 1, height: 1), animated: true)
    }
    
    @objc fileprivate func loadPreviousPage(_ sender: UIKeyCommand) {
        loadPage(page - 1, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc fileprivate func loadNextPage(_ sender: UIKeyCommand) {
        loadPage(page + 1, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc fileprivate func goToParentForum() {
        guard let forum = thread.forum else { return }
        let url = URL(string: "awful://forums/\(forum.forumID)")!
        AppDelegate.instance.openAwfulURL(url)
    }
    
    @objc fileprivate func showHiddenSeenPosts() {
        let end = hiddenPosts
        hiddenPosts = 0
        
        let html = (0..<end).map(renderedPostAtIndex).joined(separator: "\n")
        webViewJavascriptBridge?.callHandler("prependPosts", data: html)
    }
    
    @objc fileprivate func scrollToBottom(_ sender: UIKeyCommand) {
        scrollToBottom()
    }
    
    @objc fileprivate func scrollToTop(_ sender: UIKeyCommand) {
        webView.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
    }
    
    @objc fileprivate func scrollUp(_ sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        scrollView.contentOffset.y = max(scrollView.contentOffset.y - 80, 0)
    }
    
    @objc fileprivate func scrollDown(_ sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y + 80
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            let newOffset = CGPoint(x: scrollView.contentOffset.x, y: proposedOffset)
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }
    
    @objc fileprivate func pageUp(_ sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y - (scrollView.bounds.height - 80)
        let newOffset = CGPoint(x: scrollView.contentOffset.x, y: max(proposedOffset, 0))
        scrollView.setContentOffset(newOffset, animated: true)
    }
    
    @objc fileprivate func pageDown(_ sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y + (scrollView.bounds.height - 80)
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: proposedOffset), animated: true)
        }
    }
    
    @objc fileprivate func didLongPressOnPostsView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        var location = sender.location(in: webView)
        let scrollView = webView.scrollView
        location.y -= scrollView.contentInset.top
        if scrollView.contentOffset.y < 0 {
            location.y += scrollView.contentOffset.y
        }
        
        let data: [String: AnyObject] = ["x": location.x as AnyObject, "y": location.y as AnyObject]
        webViewJavascriptBridge?.callHandler("interestingElementsAtPoint", data: data, responseCallback: { [weak self] (elementInfo) in
            _ = self?.webView.stringByEvaluatingJavaScript(from: "Awful.preventNextClickEvent()")
            
            guard
                let elementInfo = elementInfo as? [String: AnyObject] , !elementInfo.isEmpty,
                let strongSelf = self
                else { return }
            
            let ok = URLMenuPresenter.presentInterestingElements(elementInfo, fromViewController: strongSelf, fromWebView: strongSelf.webView)
            guard ok || elementInfo["unspoiledLink"] != nil else {
                print("\(#function) unexpected interesting elements for data \(data) response: \(elementInfo)")
                return
            }
        })
    }
    
    fileprivate func renderedPostAtIndex(_ i: Int) -> String {
        let viewModel = PostViewModel(post: posts[i])
        do {
            return try GRMustacheTemplate.renderObject(viewModel, fromResource: "Post", bundle: nil)
        } catch {
            print("\(#function) error rendering post at index \(i): \(error)")
            return ""
        }
    }
    
    fileprivate func readIgnoredPostAtIndex(_ i: Int) {
        let post = posts[i]
        _ = ForumsClient.shared.readIgnoredPost(post)
            .then { [weak self] () -> Void in
                // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
                guard
                    let sself = self,
                    var i = sself.posts.index(of: post)
                    else { return }
                i -= sself.hiddenPosts
                guard i >= 0 else { return }
                let data: [String: AnyObject] = ["index": i as NSNumber, "HTML": sself.renderedPostAtIndex(i) as NSString]
                sself.webViewJavascriptBridge?.callHandler("postHTMLAtIndex", data: data)
            }
            .catch { [weak self] (error) -> Void in
                let alert = UIAlertController.alertWithNetworkError(error)
                self?.present(alert, animated: true)
        }
    }
    
    fileprivate func didTapUserHeaderWithRect(_ rect: CGRect, forPostAtIndex postIndex: Int) {
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
                postsVC.loadPage(1, updatingCache: true, updatingLastReadPost: true)
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
        
        actionVC.items = items
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            guard let rectString = self.webView.stringByEvaluatingJavaScript(from: "HeaderRectForPostAtIndex(\(postIndex))") else { return }
            sourceRect.pointee = self.webView.rectForElementBoundingRect(rectString)
            sourceView.pointee = self.webView
        }
        
        present(actionVC, animated: true, completion: nil)
    }
    
    fileprivate func didTapActionButtonWithRect(_ rect: CGRect, forPostAtIndex postIndex: Int) {
        assert(postIndex + hiddenPosts < posts.count, "post \(postIndex) beyond range (hiding \(hiddenPosts) posts")
        
        let post = posts[postIndex + hiddenPosts]
        let possessiveUsername: String
        if post.author?.username == AwfulSettings.shared().username {
            possessiveUsername = "Your"
        } else {
            possessiveUsername = "\(post.author?.username ?? "")'s"
        }
        
        // Filled in once the action popover is presented.
        var popoverSourceRect: CGRect = .zero
        var popoverSourceView: UIView? = nil
        
        var items: [IconActionItem] = []
        
        let shareItem = IconActionItem(.copyURL, block: {
            let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
            var queryItems = [
                URLQueryItem(name: "threadid", value: self.thread.threadID),
                URLQueryItem(name: "perpage", value: "40"),
            ]
            if self.page > 1 {
                queryItems.append(URLQueryItem(name: "pagenumber", value: "\(self.page)"))
            }
            components.queryItems = queryItems
            components.fragment = "post\(post.postID)"
            let url = components.url!
            
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity(), ARChromeActivity()])
            activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
                if completed && activityType == UIActivityType.copyToPasteboard {
                    AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                }
            }
            self.present(activityVC, animated: false, completion: nil)
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = popoverSourceView
                popover.sourceRect = popoverSourceRect
            }
        })
        shareItem.title = "Share URL"
        items.append(shareItem)
        
        if author == nil {
            items.append(IconActionItem(.markReadUpToHere, block: {
                _ = ForumsClient.shared.markThreadAsReadUpTo(post)
                    .then { [weak self] () -> Void in
                        post.thread?.seenPosts = post.threadIndex

                        self?.webViewJavascriptBridge?.callHandler("markReadUpToPostWithID", data: post.postID)

                        guard let view = self?.view else { return }
                        let overlay = MRProgressOverlayView.showOverlayAdded(to: view, title: "Marked Read", mode: .checkmark, animated: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            overlay?.dismiss(true)
                        }
                    }
                    .catch { [weak self] (error) -> Void in
                        let alert = UIAlertController(title: "Could Not Mark Read", error: error)
                        self?.present(alert, animated: true, completion: nil)
                }
            }))
        }
        
        if post.editable {
            items.append(IconActionItem(.editPost, block: {
                _ = ForumsClient.shared.findBBcodeContents(of: post)
                    .then { [weak self] (text) -> Void in
                        guard let sself = self else { return }
                        let replyWorkspace = ReplyWorkspace(post: post)
                        sself.replyWorkspace = replyWorkspace
                        replyWorkspace.completion = sself.replyCompletionBlock
                        sself.present(replyWorkspace.viewController, animated: true)
                    }
                    .catch { [weak self] (error) -> Void in
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
                        let alert = UIAlertController.alertWithNetworkError(error)
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
                guard let url = URL(string: "awful://posts/\(post.postID)") else { return }
                AppDelegate.instance.openAwfulURL(url)
            }))
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = items
        actionVC.title = "\(possessiveUsername) Post"
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            guard let rectString = self.webView.stringByEvaluatingJavaScript(from: "ActionButtonRectForPostAtIndex(\(postIndex))") else { return }
            popoverSourceRect = self.webView.rectForElementBoundingRect(rectString)
            sourceRect.pointee = popoverSourceRect
            popoverSourceView = self.webView
            sourceView.pointee = popoverSourceView!
        }
        present(actionVC, animated: true, completion: nil)
    }
    
    fileprivate func configureUserActivityIfPossible() {
        guard page >= 1 && AwfulSettings.shared().handoffEnabled else {
            userActivity = nil
            return
        }
        
        userActivity = NSUserActivity(activityType: Handoff.ActivityTypeBrowsingPosts)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.title = thread.title
        activity.addUserInfoEntries(from: [
            Handoff.InfoThreadIDKey: thread.threadID,
            Handoff.InfoPageKey: page,
            ])
        
        if let author = author {
            activity.addUserInfoEntries(from: [Handoff.InfoFilteredThreadUserIDKey: author.userID])
        }
        
        guard
            let baseURL = ForumsClient.shared.baseURL,
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
            else { return }
        components.path = "showthread.php"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "threadid", value: thread.threadID),
            URLQueryItem(name: "perpage", value: "\(40)"),
        ]
        if page >= 1 {
            queryItems.append(URLQueryItem(name: "pagenumber", value: "\(page)"))
        }
        if let author = author {
            queryItems.append(URLQueryItem(name: "userid", value: author.userID))
        }
        activity.webpageURL = components.url
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        postsView.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        
        webViewJavascriptBridge?.callHandler("changeStylesheet", data: theme["postsViewCSS"] as String?)
        
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
    
    override func loadView() {
        view = PostsView()
        
        let topBar = postsView.topBar
        topBar.parentForumButton.addTarget(self, action: #selector(goToParentForum), for: .touchUpInside)
        topBar.previousPostsButton.addTarget(self, action: #selector(showHiddenSeenPosts), for: .touchUpInside)
        topBar.previousPostsButton.isEnabled = hiddenPosts > 0
        topBar.scrollToBottomButton.addTarget(self, action: #selector(scrollToBottom as () -> Void), for: .touchUpInside)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressOnPostsView))
        longPress.delegate = self
        webView.addGestureRecognizer(longPress)
        
        let activityIndicatorManager = WebViewNetworkActivityIndicatorManager(nextDelegate: self)
        webViewNetworkActivityIndicatorManager = activityIndicatorManager
        
        webViewJavascriptBridge = WebViewJavascriptBridge(for: webView, webViewDelegate: activityIndicatorManager, handler: { (data, callback) in
            print("\(#function) webViewJavascriptBridge got \(String(describing: data))")
        })
        
        webViewJavascriptBridge?.registerHandler("didTapUserHeader", handler: { [weak self] (data, callback) in
            guard let
                data = data as? [String: AnyObject],
                let rectString = data["rect"] as? String,
                let rect = self?.webView.rectForElementBoundingRect(rectString),
                let postIndex = data["postIndex"] as? Int
                else { return }
            self?.didTapUserHeaderWithRect(rect, forPostAtIndex: postIndex)
        })
        
        webViewJavascriptBridge?.registerHandler("didTapActionButton", handler: { [weak self] (data, callback) in
            guard let
                data = data as? [String: AnyObject],
                let rectString = data["rect"] as? String,
                let rect = self?.webView.rectForElementBoundingRect(rectString),
                let postIndex = data["postIndex"] as? Int
                else { return }
            self?.didTapActionButtonWithRect(rect, forPostAtIndex: postIndex)
        })
        
        webViewJavascriptBridge?.registerHandler("didFinishLoadingTweets", handler: { [weak self] (data, callback) in
            if let postID = self?.jumpToPostIDAfterLoading {
                print("jumping to post from tweet load handler")
                self?.webViewJavascriptBridge?.callHandler("jumpToPostWithID", data: postID)
            }
            
            else if let fraction = self?.scrollToFractionAfterLoading, fraction > 0 {
                self?.webViewJavascriptBridge?.callHandler("jumpToFractionalOffset", data: fraction)
            }
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(externalStylesheetDidUpdate), name: NSNotification.Name(rawValue: PostsViewExternalStylesheetLoader.didUpdateNotification), object: nil)
        
        if AwfulSettings.shared().pullForNext {
            refreshControl = PostsPageRefreshControl(scrollView: webView.scrollView, contentView: PostsPageRefreshSpinnerView())
            refreshControl?.handler = { [weak self] in
                self?.loadNextPageOrRefresh()
            }
            refreshControl?.tintColor = theme["postsPullForNextColor"]
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
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(thread.objectKey, forKey: Keys.ThreadKey.rawValue)
        coder.encode(page, forKey: Keys.Page.rawValue)
        coder.encode(author?.objectKey, forKey: Keys.AuthorUserKey.rawValue)
        coder.encode(hiddenPosts, forKey: Keys.HiddenPosts.rawValue)
        coder.encode(messageViewController, forKey: Keys.MessageViewController.rawValue)
        coder.encode(advertisementHTML, forKey: Keys.AdvertisementHTML.rawValue)
        coder.encode(Float(webView.fractionalContentOffset), forKey: Keys.ScrolledFractionOfContent.rawValue)
        coder.encode(replyWorkspace, forKey: Keys.ReplyWorkspace.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        restoringState = true
        
        super.decodeRestorableState(with: coder)
        
        messageViewController = coder.decodeObject(forKey: Keys.MessageViewController.rawValue) as? MessageComposeViewController
        messageViewController?.delegate = self
        
        hiddenPosts = coder.decodeInteger(forKey: Keys.HiddenPosts.rawValue)
        page = coder.decodeInteger(forKey: Keys.Page.rawValue)
        loadPage(page, updatingCache: false, updatingLastReadPost: true)
        if posts.isEmpty {
            loadPage(page, updatingCache: true, updatingLastReadPost: true)
        }
        
        advertisementHTML = coder.decodeObject(forKey: Keys.AdvertisementHTML.rawValue) as? String
        scrollToFractionAfterLoading = CGFloat(coder.decodeFloat(forKey: Keys.ScrolledFractionOfContent.rawValue))
        
        replyWorkspace = coder.decodeObject(forKey: Keys.ReplyWorkspace.rawValue) as? ReplyWorkspace
        replyWorkspace?.completion = replyCompletionBlock
    }
    
    override func applicationFinishedRestoringState() {
        super.applicationFinishedRestoringState()
        
        restoringState = false
    }
}

extension PostsPageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
    }
}

extension PostsPageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

/// Twitter and YouTube embeds try to use taps to take over the frame. Here we try to detect that and treat it as if a link was tapped.
fileprivate func isHijackingWebView(_ navigationType: UIWebViewNavigationType, url: URL) -> Bool {
    guard case .other = navigationType else { return false }
    guard let host = url.host?.lowercased() else { return false }
    if host.hasSuffix("www.youtube.com") && url.path.lowercased().hasPrefix("/watch") {
        return true
    } else if
        host.hasSuffix("twitter.com"),
        let thirdComponent = url.pathComponents.dropFirst(2).first,
        thirdComponent.lowercased() == "status"
    {
        return true
    } else {
        return false
    }
}

extension PostsPageViewController: UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.url else { return true }
        guard navigationType == .linkClicked || isHijackingWebView(navigationType, url: url) else { return true }
        
        if let awfulURL = url.awfulURL {
            if url.fragment == "awful-ignored" {
                let postID = awfulURL.lastPathComponent
                if let i = posts.index(where: { $0.postID == postID }) {
                    readIgnoredPostAtIndex(i)
                }
            } else {
                AppDelegate.instance.openAwfulURL(awfulURL)
            }
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.openURL(url)
        }
        return false
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        guard !webViewDidLoadOnce && webView.request?.url?.absoluteString != "about:blank" else { return }
        
        if AwfulSettings.shared().embedTweets {
            webViewJavascriptBridge?.callHandler("embedTweets")
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
            webViewJavascriptBridge?.callHandler("jumpToPostWithID", data: postID)
        } else if let fractionalOffset = scrollToFractionAfterLoading {
            self.webViewJavascriptBridge?.callHandler("jumpToFractionalOffset", data: fractionalOffset)
        }
        
        clearLoadingMessage()
        
    }
}

extension PostsPageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        let context = AppDelegate.instance.managedObjectContext
        guard let
            threadKey = coder.decodeObject(forKey: Keys.ThreadKey.rawValue) as? ThreadKey,
            let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: context) as? AwfulThread
            else { return nil }
        let userKey = coder.decodeObject(forKey: Keys.AuthorUserKey.rawValue) as? UserKey
        let author: User?
        if let userKey = userKey {
            author = User.objectForKey(objectKey: userKey, inManagedObjectContext: context) as? User
        } else {
            author = nil
        }
        
        let postsVC = PostsPageViewController(thread: thread, author: author)
        postsVC.restorationIdentifier = identifierComponents.last as? String
        return postsVC
    }
}

fileprivate enum Keys: String {
    case ThreadKey
    case Page = "AwfulCurrentPage"
    case AuthorUserKey = "AuthorUserKey"
    case HiddenPosts = "AwfulHiddenPosts"
    case ReplyViewController = "AwfulReplyViewController"
    case MessageViewController = "AwfulMessageViewController"
    case AdvertisementHTML = "AwfulAdvertisementHTML"
    case ScrolledFractionOfContent = "AwfulScrolledFractionOfContentSize"
    case ReplyWorkspace = "Reply workspace"
}

extension PostsPageViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        return previewActionItemProvider?.previewActionItems ?? []
    }
}

extension PostsPageViewController {
    override var keyCommands: [UIKeyCommand]? {
        var keyCommands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: [], action: #selector(scrollUp), discoverabilityTitle: "Up"),
            UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: [], action: #selector(scrollDown), discoverabilityTitle: "Down"),
            UIKeyCommand(input: " ", modifierFlags: .shift, action: #selector(pageUp), discoverabilityTitle: "Page Up"),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(pageDown), discoverabilityTitle: "Page Down"),
            UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: .command, action: #selector(scrollToTop), discoverabilityTitle: "Scroll to Top"),
            UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: .command, action: #selector(scrollToBottom(_:)), discoverabilityTitle: "Scroll to Bottom"),
        ]
        
        if page > 1 {
            keyCommands.append(UIKeyCommand(input: "[", modifierFlags: .command, action: #selector(loadPreviousPage), discoverabilityTitle: "Previous Page"))
        }
        
        if page < numberOfPages {
            keyCommands.append(UIKeyCommand(input: "]", modifierFlags: .command, action: #selector(loadNextPage), discoverabilityTitle: "Next Page"))
        }
        
        keyCommands.append(UIKeyCommand(input: "N", modifierFlags: .command, action: #selector(newReply), discoverabilityTitle: "New Reply"))
        
        return keyCommands
    }
}
