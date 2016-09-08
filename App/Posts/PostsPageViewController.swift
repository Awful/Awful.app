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
    private let author: User?
    private(set) var page = 0
    private var hiddenPosts = 0 {
        didSet { updateUserInterface() }
    }
    private var webViewDidLoadOnce = false
    private var advertisementHTML: String?
    private var networkOperation: Operation?
    private var refreshControl: PostsPageRefreshControl?
    private var loadingView: LoadingView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let loadingView = loadingView , isViewLoaded {
                view.addSubview(loadingView)
            }
        }
    }
    private var webViewNetworkActivityIndicatorManager: WebViewNetworkActivityIndicatorManager?
    private var webViewJavascriptBridge: WebViewJavascriptBridge?
    private var replyWorkspace: ReplyWorkspace?
    private var messageViewController: MessageComposeViewController?
    private var jumpToPostIDAfterLoading: String?
    private var jumpToLastPost = false
    private var scrollToFractionAfterLoading: CGFloat?
    private var restoringState = false
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
            UIBarButtonItem.fixedSpace(width: spacerWidth),
            currentPageItem,
            UIBarButtonItem.fixedSpace(width: spacerWidth),
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
    
    private var postsView: PostsView {
        return view as! PostsView
    }
    
    private var webView: UIWebView {
        return postsView.webView
    }
    
    /**
        Changes the page.
     
        - parameter page: The page to load. Values of AwfulThreadPage are allowed here too (but it's typed NSInteger for Swift compatibility).
        - parameter updateCache: Whether to fetch posts from the client, or simply render any posts that are cached.
        - parameter updateLastReadPost: Whether to advance the "last-read post" marker on the Forums.
     */
    func loadPage(rawPage: Int, updatingCache: Bool, updatingLastReadPost updateLastReadPost: Bool) {
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
        
        networkOperation = AwfulForumsClient.shared().listPosts(in: thread, writtenBy: author, onPage: rawPage, updateLastReadPost: updateLastReadPost, andThen: { [weak self] (error: Error?, posts: [Any]?, firstUnreadPost, advertisementHTML: String?) in
            guard let strongSelf = self else { return }
            
            // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
            if strongSelf.page != rawPage { return }
            
            if let error = error as NSError? {
                strongSelf.clearLoadingMessage()
                
                if error.code == AwfulErrorCodes.archivesRequired {
                    let alert = UIAlertController(title: "Archives Required", error: error)
                    strongSelf.present(alert, animated: true, completion: nil)
                } else {
                    let offlineMode = !AwfulForumsClient.shared().reachable && error.domain == NSURLErrorDomain
                    if strongSelf.posts.isEmpty || !offlineMode {
                        let alert = UIAlertController(title: "Could Not Load Page", error: error)
                        strongSelf.present(alert, animated: true, completion: nil)
                    }
                }
            }
            
            if let posts = posts as? [Post] , !posts.isEmpty {
                strongSelf.posts = posts
                
                let anyPost = posts[0]
                if strongSelf.author != nil {
                    strongSelf.page = anyPost.singleUserPage
                } else {
                    strongSelf.page = anyPost.page
                }
            }
            
            if strongSelf.posts.isEmpty && rawPage < 0 {
                let pageCount = strongSelf.numberOfPages > 0 ? "\(strongSelf.numberOfPages)" : "?"
                strongSelf.currentPageItem.title = "Page ? of \(pageCount)"
            }
            
            if error != nil {
                return
            }
            
            strongSelf.configureUserActivityIfPossible()
            
            if strongSelf.hiddenPosts == 0 && Int(firstUnreadPost) != NSNotFound {
                strongSelf.hiddenPosts = Int(firstUnreadPost)
            }
            
            if reloadingSamePage || renderedCachedPosts {
                strongSelf.scrollToFractionAfterLoading = strongSelf.webView.fractionalContentOffset
            }
            
            strongSelf.renderPosts()
            
            strongSelf.updateUserInterface()
            
            if let lastPost = strongSelf.posts.last , updateLastReadPost {
                if strongSelf.thread.seenPosts < lastPost.threadIndex {
                    strongSelf.thread.seenPosts = lastPost.threadIndex
                }
            }
            
            strongSelf.refreshControl?.endRefreshing()
        })
    }
    
    /// Scroll the posts view so that a particular post is visible (if the post is on the current(ly loading) page).
    func scrollPostToVisible(post: Post) {
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
        loadPage(rawPage: AwfulThreadPage.last.rawValue, updatingCache: true, updatingLastReadPost: true)
        jumpToLastPost = true
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    private func renderPosts() {
        loadBlankPage()
        
        webViewDidLoadOnce = false
        
        var context: [String: AnyObject] = [:]
        
        var error: NSError? = nil
        if let script = LoadJavaScriptResources(["WebViewJavascriptBridge.js.txt", "zepto.min.js", "widgets.js", "common.js", "posts-view.js"], &error) {
            context["script"] = script
        } else {
            print("\(#function) error loading scripts: \(error!)")
            return
        }
        
        context["version"] = Bundle.mainBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        context["userInterfaceIdiom"] = UIDevice.currentDevice.userInterfaceIdiom == .Pad ? "ipad" : "iphone"
        context["stylesheet"] = theme["postsViewCSS"] as String?
        
        if posts.count > hiddenPosts {
            context["posts"] = posts[hiddenPosts..<posts.endIndex].map(PostViewModel.init)
        }
        
        if let ad = advertisementHTML , !ad.isEmpty {
            context["advertisementHTML"] = ad
        }
        
        if context["posts"] != nil && page > 0 && page >= numberOfPages {
            context["endMessage"] = true
        }
        
        let fontScalePercentage = AwfulSettings.shared().fontScale
        if fontScalePercentage != 100 {
            context["fontScalePercentage"] = fontScalePercentage
        }
        
        if let username = AwfulSettings.shared().username , !username.isEmpty {
            context["loggedInUsername"] = username
        }
        
        context["externalStylesheet"] = PostsViewExternalStylesheetLoader.sharedLoader.stylesheet
        
        if !thread.threadID.isEmpty {
            context["threadID"] = thread.threadID
        }
        
        if let forum = thread.forum , !forum.forumID.isEmpty {
            context["forumID"] = forum.forumID
        }
        
        do {
            let html = try GRMustacheTemplate.renderObject(context, fromResource: "PostsView", bundle: nil)
            webView.loadHTMLString(html, baseURL: AwfulForumsClient.shared().baseURL)
        } catch {
            print("\(#function) error loading posts view HTML: \(error)")
        }
    }
    
    private func loadBlankPage() {
        let request = NSURLRequest(URL: NSURL(string: "about:blank")! as URL)
        webView.loadRequest(request as URLRequest)
    }
    
    private lazy var composeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = "Reply to thread"
        item.actionBlock = { [weak self] (sender) in
            guard let strongSelf = self else { return }
            if strongSelf.replyWorkspace == nil {
                strongSelf.replyWorkspace = ReplyWorkspace(post: strongSelf.thread)
                strongSelf.replyWorkspace?.completion = strongSelf.replyCompletionBlock
            }
            strongSelf.present(strongSelf.replyWorkspace!.viewController, animated: true, completion: nil)
        }
        return item
    }()
    
    @objc private func newReply(sender: UIKeyCommand) {
        if replyWorkspace == nil {
            replyWorkspace = ReplyWorkspace(post: thread)
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
                self?.loadPage(rawPage: AwfulThreadPage.nextUnread.rawValue, updatingCache: true, updatingLastReadPost: true)
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
            guard self.page > 1 else { return }
            self.loadPage(rawPage: self.page - 1, updatingCache: true, updatingLastReadPost: true)
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
            guard self.page < self.numberOfPages && self.page > 0 else { return }
            self.loadPage(rawPage: self.page + 1, updatingCache: true, updatingLastReadPost: true)
        }
        return item
    }()
    
    private lazy var actionsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(named: "action"), style: .plain, target: nil, action: nil)
        item.actionBlock = { [unowned self] (sender) in
            let actionVC = InAppActionViewController()
            actionVC.title = self.title
            
            let copyURLItem = IconActionItem(.CopyURL, block: { 
                let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
                var queryItems = [
                    NSURLQueryItem(name: "threadid", value: self.thread.threadID),
                    NSURLQueryItem(name: "perpage", value: "40"),
                ]
                if self.page > 1 {
                    queryItems.append(NSURLQueryItem(name: "pagenumber", value: "\(self.page)"))
                }
                components.queryItems = queryItems
                let url = components.url!
                
                AwfulSettings.shared().lastOfferedPasteboardURL = url.absoluteString
                UIPasteboard.general.awful_URL = url
            })
            copyURLItem.title = "Copy URL"
            
            let voteItem = IconActionItem(.Vote, block: { [unowned self] in
                let actionSheet = UIAlertController.actionSheet()
                for i in 5.stride(to: 0, by: -1) {
                    actionSheet.addActionWithTitle(title: "\(i)", handler: {
                        let overlay = MRProgressOverlayView.showOverlayAdded(to: self.view, title: "Voting \(i)", mode: .indeterminate, animated: true)
                        overlay?.tintColor = self.theme["tintColor"]
                        
                        AwfulForumsClient.shared().rateThread(self.thread, i, andThen: { [weak self] (error: NSError?) in
                            if let error = error {
                                overlay.dismiss(false)
                                
                                let alert = UIAlertController(title: "Vote Failed", error: error)
                                self?.presentViewController(alert, animated: true, completion: nil)
                                return
                            }
                            
                            overlay.mode = .Checkmark
                            
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.7 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                                overlay.dismiss(true)
                            }
                        })
                    })
                }
                actionSheet.addCancelActionWithHandler(handler: nil)
                self.present(actionSheet, animated: false, completion: nil)
                
                if let popover = actionSheet.popoverPresentationController {
                    popover.barButtonItem = sender
                }
            })
            
            let bookmarkType: IconAction = self.thread.bookmarked ? .RemoveBookmark : .AddBookmark
            let bookmarkItem = IconActionItem(bookmarkType, block: {
                AwfulForumsClient.shared().setThread(self.thread, isBookmarked: !self.thread.bookmarked, andThen: { [weak self] (error: NSError?) in
                    if let error = error {
                        print("\(#function) error marking thread: \(error)")
                        return
                    }
                    
                    guard let strongSelf = self else { return }
                    
                    let status = strongSelf.thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAddedTo(strongSelf.view, title: status, mode: .Checkmark, animated: true)
                    overlay.tintColor = strongSelf.theme["tintColor"]
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.7 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                        overlay.dismiss(true)
                    }
                })
            })
            
            actionVC.items = [copyURLItem, voteItem, bookmarkItem]
            self.present(actionVC, animated: true, completion: nil)
            
            if let popover = actionVC.popoverPresentationController {
                popover.barButtonItem = sender
            }
        }
        return item
    }()
    
    @objc private func settingsDidChange(notification: NSNotification) {
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
    
    @objc private func externalStylesheetDidUpdate(notification: NSNotification) {
        webViewJavascriptBridge?.callHandler("changeExternalStylesheet", data: notification.object)
    }
    
    private func refetchPosts() {
        guard page >= 1 else {
            posts = []
            return
        }
        
        let request = NSFetchRequest(entityName: Post.entityName())
        
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
            posts = try context.executeFetchRequest(request) as! [Post]
        } catch {
            print("\(#function) error fetching posts: \(error)")
        }
    }
    
    private func updateUserInterface() {
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
    
    private func showLoadingView() {
        guard loadingView == nil else { return }
        loadingView = LoadingView.loadingViewWithTheme(theme: theme)
    }
    
    private func clearLoadingMessage() {
        loadingView = nil
    }
    
    private func loadNextPageOrRefresh() {
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
        
        loadPage(rawPage: nextPage, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func scrollToBottom() {
        let scrollView = webView.scrollView
        scrollView.scrollRectToVisible(CGRect(x: 0, y: scrollView.contentSize.height - 1, width: 1, height: 1), animated: true)
    }
    
    @objc private func loadPreviousPage(sender: UIKeyCommand) {
        loadPage(rawPage: page - 1, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func loadNextPage(sender: UIKeyCommand) {
        loadPage(rawPage: page + 1, updatingCache: true, updatingLastReadPost: true)
    }
    
    @objc private func goToParentForum() {
        guard let forum = thread.forum else { return }
        let url = NSURL(string: "awful://forums/\(forum.forumID)")!
        AppDelegate.instance.openAwfulURL(url: url)
    }
    
    @objc private func showHiddenSeenPosts() {
        let end = hiddenPosts
        hiddenPosts = 0
        
        let html = (0..<end).map(renderedPostAtIndex).joined(separator: "\n")
        webViewJavascriptBridge?.callHandler("prependPosts", data: html)
    }
    
    @objc private func scrollToBottom(sender: UIKeyCommand) {
        scrollToBottom()
    }
    
    @objc private func scrollToTop(sender: UIKeyCommand) {
        webView.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
    }
    
    @objc private func scrollUp(sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        scrollView.contentOffset.y = max(scrollView.contentOffset.y - 80, 0)
    }
    
    @objc private func scrollDown(sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y + 80
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            let newOffset = CGPoint(x: scrollView.contentOffset.x, y: proposedOffset)
            scrollView.setContentOffset(newOffset, animated: true)
        }
    }
    
    @objc private func pageUp(sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y - (scrollView.bounds.height - 80)
        let newOffset = CGPoint(x: scrollView.contentOffset.x, y: max(proposedOffset, 0))
        scrollView.setContentOffset(newOffset, animated: true)
    }
    
    @objc private func pageDown(sender: UIKeyCommand) {
        let scrollView = webView.scrollView
        let proposedOffset = scrollView.contentOffset.y + (scrollView.bounds.height - 80)
        if proposedOffset > scrollView.contentSize.height - scrollView.bounds.height {
            scrollToBottom()
        } else {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: proposedOffset), animated: true)
        }
    }
    
    @objc private func didLongPressOnPostsView(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        var location = sender.location(in: webView)
        let scrollView = webView.scrollView
        location.y -= scrollView.contentInset.top
        if scrollView.contentOffset.y < 0 {
            location.y += scrollView.contentOffset.y
        }
        
        let data: [String: AnyObject] = ["x": location.x as AnyObject, "y": location.y as AnyObject]
        webViewJavascriptBridge?.callHandler("interestingElementsAtPoint", data: data, responseCallback: { [weak self] (elementInfo) in
            self?.webView.stringByEvaluatingJavaScript(from: "Awful.preventNextClickEvent()")
            
            guard
                let elementInfo = elementInfo as? [String: AnyObject] , !elementInfo.isEmpty,
                let strongSelf = self
                else { return }
            
            let ok = URLMenuPresenter.presentInterestingElements(info: elementInfo, fromViewController: strongSelf, fromWebView: strongSelf.webView)
            guard ok || elementInfo["unspoiledLink"] != nil else {
                print("\(#function) unexpected interesting elements for data \(data) response: \(elementInfo)")
                return
            }
        })
    }
    
    private func renderedPostAtIndex(i: Int) -> String {
        let viewModel = PostViewModel(post: posts[i])
        do {
            return try GRMustacheTemplate.renderObject(viewModel, fromResource: "Post", bundle: nil)
        } catch {
            print("\(#function) error rendering post at index \(i): \(error)")
            return ""
        }
    }
    
    private func readIgnoredPostAtIndex(i: Int) {
        let post = posts[i]
        AwfulForumsClient.sharedClient().readIgnoredPost(post) { [weak self] (error: NSError?) in
            if let error = error {
                let alert = UIAlertController.alertWithNetworkError(error)
                self?.presentViewController(alert, animated: true, completion: nil)
                return
            }
            
            // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
            guard
                let strongSelf = self,
                var i = strongSelf.posts.indexOf(post)
                else { return }
            i -= strongSelf.hiddenPosts ?? 0
            guard i >= 0 else { return }
            let data: [String: AnyObject] = ["index": i, "HTML": strongSelf.renderedPostAtIndex(i)]
            strongSelf.webViewJavascriptBridge?.callHandler("postHTMLAtIndex", data: data)
        }
    }
    
    private func didTapUserHeaderWithRect(rect: CGRect, forPostAtIndex postIndex: Int) {
        let post = posts[postIndex + hiddenPosts]
        guard let user = post.author else { return }
        let actionVC = InAppActionViewController()
        var items: [IconActionItem] = []
        
        items.append(IconActionItem(.UserProfile, block: {
            let profileVC = ProfileViewController(user: user)
            self.present(profileVC.enclosingNavigationController, animated: true, completion: nil)
        }))
        
        if author == nil {
            items.append(IconActionItem(.SingleUsersPosts, block: {
                let postsVC = PostsPageViewController(thread: self.thread, author: user)
                postsVC.restorationIdentifier = "Just their posts"
                postsVC.loadPage(rawPage: 1, updatingCache: true, updatingLastReadPost: true)
                self.navigationController?.pushViewController(postsVC, animated: true)
            }))
        }
        
        if
            AwfulSettings.shared().canSendPrivateMessages &&
            user.canReceivePrivateMessages &&
            user.userID != AwfulSettings.shared().userID
        {
            items.append(IconActionItem(.SendPrivateMessage, block: {
                let messageVC = MessageComposeViewController(recipient: user)
                self.messageViewController = messageVC
                messageVC.delegate = self
                messageVC.restorationIdentifier = "New PM from posts view"
                self.present(messageVC.enclosingNavigationController, animated: true, completion: nil)
            }))
        }
        
        items.append(IconActionItem(.RapSheet, block: {
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
            sourceRect.memory = self.webView.rectForElementBoundingRect(rectString)
            sourceView.memory = self.webView
        }
        
        present(actionVC, animated: true, completion: nil)
    }
    
    private func didTapActionButtonWithRect(rect: CGRect, forPostAtIndex postIndex: Int) {
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
        
        let shareItem = IconActionItem(.CopyURL, block: {
            let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
            var queryItems = [
                NSURLQueryItem(name: "threadid", value: self.thread.threadID),
                NSURLQueryItem(name: "perpage", value: "40"),
            ]
            if self.page > 1 {
                queryItems.append(NSURLQueryItem(name: "pagenumber", value: "\(self.page)"))
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
            items.append(IconActionItem(.MarkReadUpToHere, block: {
                AwfulForumsClient.sharedClient().markThreadReadUpToPost(post, andThen: { [weak self] (error: NSError?) in
                    if let error = error {
                        let alert = UIAlertController(title: "Could Not Mark Read", error: error)
                        self?.presentViewController(alert, animated: true, completion: nil)
                        return
                    }
                    
                    post.thread?.seenPosts = post.threadIndex
                    
                    self?.webViewJavascriptBridge?.callHandler("markReadUpToPostWithID", data: post.postID)
                    
                    guard let view = self?.view else { return }
                    let overlay = MRProgressOverlayView.showOverlayAddedTo(view, title: "Marked Read", mode: .Checkmark, animated: true)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.7 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                        overlay.dismiss(true)
                    }
                })
            }))
        }
        
        if post.editable {
            items.append(IconActionItem(.EditPost, block: {
                AwfulForumsClient.sharedClient().findBBcodeContentsWithPost(post, andThen: { [weak self] (error: NSError?, text: String?) in
                    if let error = error {
                        let alert = UIAlertController(title: "Could Not Edit Post", error: error)
                        self?.presentViewController(alert, animated: true, completion: nil)
                        return
                    }
                    
                    let replyWorkspace = ReplyWorkspace(post: post)
                    self?.replyWorkspace = replyWorkspace
                    replyWorkspace.completion = self?.replyCompletionBlock
                    self?.presentViewController(replyWorkspace.viewController, animated: true, completion: nil)
                })
            }))
        }
        
        if !thread.closed {
            items.append(IconActionItem(.QuotePost, block: {
                if self.replyWorkspace == nil {
                    self.replyWorkspace = ReplyWorkspace(post: self.thread)
                    self.replyWorkspace?.completion = self.replyCompletionBlock
                }
                
                self.replyWorkspace?.quotePost(post: post, completion: { [weak self] (error) in
                    if let error = error {
                        let alert = UIAlertController.alertWithNetworkError(error: error)
                        self?.present(alert, animated: true, completion: nil)
                        return
                    }
                    
                    guard let vc = self?.replyWorkspace?.viewController else { return }
                    self?.present(vc, animated: true, completion: nil)
                })
            }))
        }
        
        items.append(IconActionItem(.ReportPost, block: {
            let reportVC = ReportPostViewController(post: post)
            self.present(reportVC.enclosingNavigationController, animated: true, completion: nil)
        }))
        
        if author != nil {
            items.append(IconActionItem(.ShowInThread, block: {
                // This will add the thread to the navigation stack, giving us thread->author->thread.
                guard let url = NSURL(string: "awful://posts/\(post.postID)") else { return }
                AppDelegate.instance.openAwfulURL(url: url)
            }))
        }
        
        let actionVC = InAppActionViewController()
        actionVC.items = items
        actionVC.title = "\(possessiveUsername) Post"
        actionVC.popoverPositioningBlock = { (sourceRect, sourceView) in
            guard let rectString = self.webView.stringByEvaluatingJavaScript(from: "ActionButtonRectForPostAtIndex(\(postIndex))") else { return }
            popoverSourceRect = self.webView.rectForElementBoundingRect(rectString: rectString)
            sourceRect.memory = popoverSourceRect
            popoverSourceView = self.webView
            sourceView.memory = popoverSourceView
        }
        present(actionVC, animated: true, completion: nil)
    }
    
    private func configureUserActivityIfPossible() {
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
        
        guard let components = NSURLComponents(URL: AwfulForumsClient.shared().baseURL, resolvingAgainstBaseURL: true) else { return }
        components.path = "showthread.php"
        var queryItems: [NSURLQueryItem] = [
            NSURLQueryItem(name: "threadid", value: thread.threadID),
            NSURLQueryItem(name: "perpage", value: "\(40)"),
        ]
        if page >= 1 {
            queryItems.append(NSURLQueryItem(name: "pagenumber", value: "\(page)"))
        }
        if let author = author {
            queryItems.append(NSURLQueryItem(name: "userid", value: author.userID))
        }
        activity.webpageURL = components.url
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        postsView.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        
        webViewJavascriptBridge?.callHandler("changeStylesheet", data: theme["postsViewCSS"] as String?)
        
        if loadingView != nil {
            loadingView = LoadingView.loadingViewWithTheme(theme: theme)
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
        
        webViewJavascriptBridge = WebViewJavascriptBridge(forWebView: webView, webViewDelegate: activityIndicatorManager, handler: { (data, callback) in
            print("\(#function) webViewJavascriptBridge got \(data)")
        })
        
        webViewJavascriptBridge?.registerHandler("didTapUserHeader", handler: { [weak self] (data, callback) in
            guard let
                data = data as? [String: AnyObject],
                let rectString = data["rect"] as? String,
                let rect = self?.webView.rectForElementBoundingRect(rectString: rectString),
                let postIndex = data["postIndex"] as? Int
                else { return }
            self?.didTapUserHeaderWithRect(rect: rect, forPostAtIndex: postIndex)
        })
        
        webViewJavascriptBridge?.registerHandler("didTapActionButton", handler: { [weak self] (data, callback) in
            guard let
                data = data as? [String: AnyObject],
                let rectString = data["rect"] as? String,
                let rect = self?.webView.rectForElementBoundingRect(rectString: rectString),
                let postIndex = data["postIndex"] as? Int
                else { return }
            self?.didTapActionButtonWithRect(rect: rect, forPostAtIndex: postIndex)
        })
        
        webViewJavascriptBridge?.registerHandler("didFinishLoadingTweets", handler: { [weak self] (data, callback) in
            if let postID = self?.jumpToPostIDAfterLoading {
                print("jumping to post from tweet load handler")
                self?.webViewJavascriptBridge?.callHandler("jumpToPostWithID", data: postID)
            }
            
            else if (self?.scrollToFractionAfterLoading > 0) {
                self?.webView.fractionalContentOffset = (self?.scrollToFractionAfterLoading!)!
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
        loadPage(rawPage: page, updatingCache: false, updatingLastReadPost: true)
        if posts.isEmpty {
            loadPage(rawPage: page, updatingCache: true, updatingLastReadPost: true)
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
    func composeTextViewController(composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
    }
}

extension PostsPageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

/// Twitter and YouTube embeds try to use taps to take over the frame. Here we try to detect that and treat it as if a link was tapped.
private func isHijackingWebView(navigationType: UIWebViewNavigationType, url: NSURL) -> Bool {
    guard case .other = navigationType else { return false }
    guard let host = url.host?.lowercased else { return false }
    if
        host.hasSuffix("www.youtube.com"),
        let path = url.path?.lowercased , path.hasPrefix("/watch")
    {
        return true
    } else if
        host.hasSuffix("twitter.com"),
        let thirdComponent = url.pathComponents?.dropFirst(2).first
        , thirdComponent.lowercased == "status"
    {
        return true
    } else {
        return false
    }
}

extension PostsPageViewController: UIWebViewDelegate {
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard let url = request.url else { return true }
        guard navigationType == .linkClicked || isHijackingWebView(navigationType: navigationType, url: url as NSURL) else { return true }
        
        if let awfulURL = url.awfulURL {
            if url.fragment == "awful-ignored" {
                guard let postID = awfulURL.lastPathComponent else { return true }
                if let i = posts.indexOf({ $0.postID == postID }) {
                    readIgnoredPostAtIndex(i)
                }
            } else {
                AppDelegate.instance.openAwfulURL(awfulURL)
            }
        } else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url as NSURL).presentInDefaultBrowser(fromViewController: self)
        } else {
            UIApplication.shared.openURL(url)
        }
        return false
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        guard !webViewDidLoadOnce && webView.request?.URL?.absoluteString != "about:blank" else { return }
        if AwfulSettings.shared().embedTweets {
            webViewJavascriptBridge?.callHandler("embedTweets")
        }
        
        webViewDidLoadOnce = true
        
        if goToLastPost {
            if posts.count > 0 {
                let lastPost = posts.max(by: { (a, b) -> Bool in
                    return a.threadIndex < b.threadIndex
                })
                if let lastPost = lastPost {
                    jumpToPostIDAfterLoading = lastPost.postID
                }
            }
        }
        
        if let postID = jumpToPostIDAfterLoading {
            webViewJavascriptBridge?.callHandler("jumpToPostWithID", data: postID)
        } else if let fractionalOffset = scrollToFractionAfterLoading {
            webView.fractionalContentOffset = fractionalOffset
        }
        
        clearLoadingMessage()
        
        
    }
}

extension PostsPageViewController: UIViewControllerRestoration {
    static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        let context = AppDelegate.instance.managedObjectContext
        guard let
            threadKey = coder.decodeObject(forKey: Keys.ThreadKey.rawValue) as? ThreadKey,
            let thread = Thread.objectForKey(threadKey, inManagedObjectContext: context) as? Thread
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

private enum Keys: String {
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
    override func previewActionItems() -> [UIPreviewActionItem] {
        return previewActionItemProvider?.previewActionItems ?? []
    }
}

extension PostsPageViewController {
    override var keyCommands: [UIKeyCommand]? {
        var keyCommands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: [], action: #selector(scrollUp), discoverabilityTitle: "Up"),
            UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: [], action: #selector(scrollDown), discoverabilityTitle: "Down"),
            UIKeyCommand(input: " ", modifierFlags: .Shift, action: #selector(page), discoverabilityTitle: "Page Up"),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(pageDown), discoverabilityTitle: "Page Down"),
            UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: .Command, action: #selector(scrollToTop), discoverabilityTitle: "Scroll to Top"),
            UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: .Command, action: #selector(scrollToBottom(_:)), discoverabilityTitle: "Scroll to Bottom"),
        ]
        
        if page > 1 {
            keyCommands.append(UIKeyCommand(input: "[", modifierFlags: .Command, action: #selector(loadPreviousPage), discoverabilityTitle: "Previous Page"))
        }
        
        if page < numberOfPages {
            keyCommands.append(UIKeyCommand(input: "]", modifierFlags: .Command, action: #selector(loadNextPage), discoverabilityTitle: "Next Page"))
        }
        
        keyCommands.append(UIKeyCommand(input: "N", modifierFlags: .Command, action: #selector(newReply), discoverabilityTitle: "New Reply"))
        
        return keyCommands
    }
}
