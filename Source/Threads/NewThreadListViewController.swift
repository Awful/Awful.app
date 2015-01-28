//  NewThreadListViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class NewThreadListViewController: AwfulViewController, ASTableViewDelegate {
    private let tableView = ASTableView()
    private let refreshControl = UIRefreshControl()
    private lazy var dataSource: NewBookmarksDataSource = { [unowned self] in
        return NewBookmarksDataSource(tableView: self.tableView, themeProvider: self) }()
    private lazy var infiniteTableController: InfiniteTableController = { [unowned self] in
        let controller = InfiniteTableController(tableView: self.tableView) { [unowned self] in
            self.loadBookmarksPage(self.mostRecentlyLoadedPage + 1)
        }
        controller.enabled = false
        return controller
        }()
    private var mostRecentlyLoadedPage = 0
    
    override init() {
        super.init(nibName: nil, bundle: nil)
        
        tableView.asyncDataSource = dataSource
        tableView.asyncDelegate = self
        
        tableView.separatorStyle = .None
        
        refreshControl.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        // HACK: UIRefreshControl is only documented to work with UITableViewController. Expect this to break at any time.
        tableView.addSubview(refreshControl)
        
        self.view = tableView
        
        title = "Bookmarks"
        tabBarItem.image = UIImage(named: "bookmarks")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadBookmarksPage(page: Int) {
        AwfulForumsClient.sharedClient().listBookmarkedThreadsOnPage(page) { [weak self] (error: NSError?, threads: [AnyObject]?) in
            if let error = error {
                if self?.visible == true {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    self?.presentViewController(alert, animated: true, completion: nil)
                }
            }
            
            if error == nil {
                self?.mostRecentlyLoadedPage = page
                AwfulRefreshMinder.sharedMinder().didFinishRefreshingBookmarks()
            }
            
            self?.refreshControl.endRefreshing()
            self?.infiniteTableController.stop()
            self?.infiniteTableController.enabled = threads?.count >= 40
        }
    }
    
    @objc private func refresh() {
        refreshControl.beginRefreshing()
        loadBookmarksPage(1)
    }
    
    private func refreshIfNecessary() {
        if !AwfulForumsClient.sharedClient().reachable { return }
        
        if dataSource.isEmpty || AwfulRefreshMinder.sharedMinder().shouldRefreshBookmarks() {
            refresh()
        }
    }
    
    // MARK: ASTableViewDelegate
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        let thread = dataSource[indexPath]
        
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.NextUnread.rawValue : 1

        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        postsViewController.loadPage(targetPage, updatingCache: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.threadsSortedByUnread, options: nil) { [unowned self] _, _, _ in
            self.dataSource = NewBookmarksDataSource(tableView: self.tableView, themeProvider: self)
            self.tableView.asyncDataSource = self.dataSource
            self.tableView.reloadData()
        }
        
        KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.showThreadTags, options: nil) { [unowned self] _, _, _ in
            self.tableView.reloadData()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        tableView.reloadData()
        refreshControl.tintColor = theme["listText"]
        infiniteTableController.spinnerColor = theme["listText"]
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshIfNecessary()
    }
}

private final class ThreadCellNode: ASCellNode {
    private let tagAndRatingNode = TagAndRatingNode()
    private let titleNode = ASTextNode()
    private let bottomLineNode = ASTextNode()
    private let unreadPostsNode = ASTextNode()
    private let separator = ASDisplayNode()
    
    var viewModel: ThreadViewModel! {
        didSet {
            tagAndRatingNode.setTagImageName(viewModel.tagImageName, placeholderImage: viewModel.missingTagImage)
            tagAndRatingNode.ratingNode.image = viewModel.ratingImage
            tagAndRatingNode.secondaryTagImage = viewModel.secondaryTagImage
            tagAndRatingNode.alpha = viewModel.tagAndRatingAlpha
            
            titleNode.attributedString = NSAttributedString(string: viewModel.title, attributes: [
                NSFontAttributeName: viewModel.titleFont,
                NSForegroundColorAttributeName: viewModel.titleColor
                ])
            bottomLineNode.attributedString = NSAttributedString(string: viewModel.bottomLine, attributes: [
                NSFontAttributeName: viewModel.bottomLineFont,
                NSForegroundColorAttributeName: viewModel.bottomLineTextColor
                ])
            unreadPostsNode.attributedString = NSAttributedString(string: viewModel.unreadPosts, attributes: [
                NSFontAttributeName: viewModel.unreadPostsFont,
                NSForegroundColorAttributeName: viewModel.unreadPostsColor
                ])
            
            backgroundColor = viewModel.backgroundColor
            titleNode.placeholderColor = viewModel.backgroundColor
            bottomLineNode.placeholderColor = viewModel.backgroundColor
            unreadPostsNode.placeholderColor = viewModel.backgroundColor
            separator.backgroundColor = viewModel.separatorColor
            
            invalidateCalculatedSize()
        }
    }
    
    private var titleAttributes: [NSObject: AnyObject] {
        return [
            NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody),
            NSForegroundColorAttributeName: viewModel.titleColor
        ]
    }
    
    override init() {
        super.init()
        addSubnode(tagAndRatingNode)
        addSubnode(titleNode)
        addSubnode(bottomLineNode)
        addSubnode(unreadPostsNode)
        addSubnode(separator)
    }
    
    private var outerInsets: UIEdgeInsets { return UIEdgeInsets(horizontal: 8, vertical: 8) }
    private struct Padding {
        static let tagRight: CGFloat = 8
        static let titleBottom: CGFloat = 4
        static let unreadPostsLeft: CGFloat = 5
    }
    
    private var titlePadding = UIEdgeInsetsZero
    
    override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
        let availableSize = constrainedSize.sizeByInsetting(outerInsets)
        let leftSize = tagAndRatingNode.measure(availableSize)
        let rightSize = unreadPostsNode.measure(availableSize)
        titlePadding = UIEdgeInsets(
            left: leftSize.width > 0 ? Padding.tagRight : 0,
            right: rightSize.width > 0 ? Padding.unreadPostsLeft : 0)
        
        let availableMiddleWidth = availableSize.width - leftSize.width - rightSize.width - titlePadding.horizontal
        let titleSize = titleNode.measure(CGSize(width: availableMiddleWidth, height: constrainedSize.height))
        let bottomLineSize = bottomLineNode.measure(CGSize(width: availableMiddleWidth, height: constrainedSize.height))
        
        let middleHeight = titleSize.height + Padding.titleBottom + bottomLineSize.height
        let requiredHeight = max(leftSize.height, middleHeight, rightSize.height)
        return CGSize(width: constrainedSize.width, height: ceil(requiredHeight + outerInsets.vertical))
    }
    
    override func layout() {
        let availableFrame = bounds.rectByInsetting(outerInsets)
        let leftSize = tagAndRatingNode.calculatedSize
        let rightSize = unreadPostsNode.calculatedSize
        let (leftPart, remainingFrame) = availableFrame.rectsByDividing(leftSize.width, fromEdge: .MinXEdge, withGap: titlePadding.left)
        let (rightPart, middlePart) = remainingFrame.rectsByDividing(rightSize.width, fromEdge: .MaxXEdge, withGap: titlePadding.right)
        
        tagAndRatingNode.frame = CGRect(size: leftSize, centeredInRect: leftPart)
        
        let titleSize = titleNode.calculatedSize
        let bottomLineSize = bottomLineNode.calculatedSize
        let combinedTextSize = CGSize(width: middlePart.width, height: titleSize.height + Padding.titleBottom + bottomLineSize.height)
        let combinedTextFrame = CGRect(size: combinedTextSize, centeredInRect: middlePart)
        let (titleFrame, bottomLineFrame) = combinedTextFrame.rectsByDividing(titleSize.height, fromEdge: .MinYEdge, withGap: Padding.titleBottom)
        titleNode.frame = titleFrame
        bottomLineNode.frame = bottomLineFrame
        
        unreadPostsNode.frame = CGRect(size: rightSize, centeredInRect: rightPart)
        
        let pixelHeight = 1 / UIScreen.mainScreen().scale
        separator.frame = CGRect(x: CGRectGetMinX(titleNode.frame), y: bounds.height - pixelHeight, width: bounds.width, height: pixelHeight)
    }
    
    private final class TagAndRatingNode: ASDisplayNode {
        
        // Public API
        
        override init() {
            super.init()
            addSubnode(ratingNode)
            addSubnode(secondaryTagNode)
        }
        
        func setTagImageName(tagImageName: String?, placeholderImage: UIImage?) {
            if let placeholderImage = placeholderImage {
                tagController = ThreadTagController(placeholderImage: placeholderImage, tagImageName: tagImageName)
            } else {
                tagController = nil
            }
        }
        
        var secondaryTagImage: UIImage? {
            get { return secondaryTagNode.image }
            set { secondaryTagNode.image = newValue }
        }
        
        var ratingImage: UIImage? {
            get { return ratingNode.image }
            set { ratingNode.image = newValue }
        }
        
        
        // Private API
        
        private let ratingNode = ASImageNode()
        private let secondaryTagNode = ASImageNode()
        private var tagController: ThreadTagController! {
            didSet {
                if let oldNode = oldValue?.node {
                    oldNode.removeFromSupernode()
                }
                if let newNode = tagController?.node {
                    insertSubnode(newNode, belowSubnode: secondaryTagNode)
                }
            }
        }
        private var tagNode: ASDisplayNode {
            return tagController.node
        }
        
        private struct Padding {
            static let tagBottom: CGFloat = 2
        }
        
        override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
            secondaryTagNode.measure(constrainedSize)
            
            let tagSize = tagNode.measure(constrainedSize)
            let ratingSize = ratingNode.measure(constrainedSize)
            if tagSize.isEmpty {
                return ratingSize
            } else if ratingSize.isEmpty {
                return tagSize
            } else {
                return CGSize(
                    width: max(tagSize.width, ratingSize.width),
                    height: tagSize.height + Padding.tagBottom + ratingSize.height)
            }
        }
        
        override func layout() {
            tagNode.frame = CGRect(size: tagNode.calculatedSize, centeredInRect: bounds)
            let ratingSize = ratingNode.calculatedSize
            ratingNode.frame = CGRect(size: ratingSize, centeredInRect: bounds)
            if !ratingSize.isEmpty {
                tagNode.frame.origin.y = 0
                ratingNode.frame.origin.y = bounds.maxY - ratingSize.height
            }
            
            let secondaryTagSize = secondaryTagNode.calculatedSize
            secondaryTagNode.frame = CGRect(origin: CGPoint(
                x: tagNode.frame.maxX - secondaryTagSize.width + 1,
                y: tagNode.frame.maxY - secondaryTagSize.height + 1),
                size: secondaryTagSize)
        }
    }
}

/// Loads a thread tag into an ASImageNode, showing a placeholder when necessary.
final private class ThreadTagController: NSObject {
    
    // Public API
    
    var node: ASDisplayNode { return imageNode }
    
    /// The placeholder image is displayed immediately. The named tag image is displayed once it's available.
    init(placeholderImage: UIImage?, tagImageName: String?) {
        imageNode.image = placeholderImage
        super.init()
        
        if let imageName = tagImageName {
            dispatch_main_async {
                if let tagImage = AwfulThreadTagLoader.imageNamed(imageName) {
                    self.imageNode.image = tagImage
                } else {
                    self.tagImageName = imageName
                    NSNotificationCenter.defaultCenter().addObserver(self, selector: "newTagImageAvailable:", name: AwfulThreadTagLoaderNewImageAvailableNotification, object: nil)
                }
            }
        }
    }
    
    
    // Private API
    
    private let imageNode = ASImageNode()
    private var tagImageName: String?
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    @objc private func newTagImageAvailable(note: NSNotification) {
        if let newImageName = note.userInfo?[AwfulThreadTagLoaderNewImageNameKey] as String? {
            if newImageName == tagImageName {
                dispatch_main_async {
                    if let tagImage = AwfulThreadTagLoader.imageNamed(self.tagImageName) {
                        self.imageNode.image = tagImage
                    }
                }
                
                NSNotificationCenter.defaultCenter().removeObserver(self, name: note.name, object: nil)
            }
        }
    }
}

/// Presents a thread to a thread cell.
private struct ThreadViewModel {
    let title: String
    let titleFont: UIFont
    let titleColor: UIColor
    
    let bottomLine: String
    let bottomLineFont: UIFont
    let bottomLineTextColor: UIColor

    let unreadPosts: String
    let unreadPostsFont: UIFont
    let unreadPostsColor: UIColor
    
    let missingTagImage: UIImage?
    let tagImageName: String?
    let ratingImage: UIImage?
    let secondaryTagImage: UIImage?
    let tagAndRatingAlpha: CGFloat
    
    let separatorColor: UIColor
    let backgroundColor: UIColor
    
    /// Must be called on the main thread. (Properties can be accessed from any thread.)
    init(thread: Thread, theme: AwfulTheme) {
        let appearsClosed = thread.closed && !thread.sticky
        
        title = thread.title ?? ""
        if appearsClosed {
            titleColor = UIColor.grayColor()
        } else {
            titleColor = theme["listText"]
        }
        
        let pages = "\(thread.numberOfPages) pages"
        if thread.beenSeen {
            let lastPoster = thread.lastPostAuthorName ?? ""
            bottomLine = "\(pages). Killed by \(lastPoster)"
        } else {
            let author = thread.author?.username ?? ""
            bottomLine = "\(pages). Posted by \(author)"
        }
        bottomLineTextColor = theme["listSecondaryText"]
        
        unreadPosts = thread.beenSeen ? "\(thread.unreadPosts)" : ""
        unreadPostsColor = {
            if thread.unreadPosts > 0 {
                switch (thread.starCategory) {
                case .Orange: return theme["unreadBadgeOrange"]
                case .Red: return theme["unreadBadgeRed"]
                case .Yellow: return theme["unreadBadgeYellow"]
                case .None: return theme["tint"]
                }
            }
            return nil
            }() ?? UIColor.grayColor()
        
        let titleFontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleBody)
        let titleFontSize = min(titleFontDescriptor.pointSize, 23)
        let otherFontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleFootnote)
        let bottomFontSize = min(otherFontDescriptor.pointSize, 19)
        let unreadFontSize = bottomFontSize + 2
        if let fontName = theme["listFontName"] as String? {
            titleFont = UIFont(name: fontName, size: titleFontSize)!
            bottomLineFont = UIFont(name: fontName, size: bottomFontSize)!
            unreadPostsFont = UIFont(name: fontName, size: unreadFontSize)!
        } else {
            titleFont = UIFont(descriptor: titleFontDescriptor, size: titleFontSize)
            bottomLineFont = UIFont(descriptor: otherFontDescriptor, size: bottomFontSize)
            unreadPostsFont = UIFont(descriptor: otherFontDescriptor, size: unreadFontSize)
        }
        
        if AwfulSettings.sharedSettings().showThreadTags {
            missingTagImage = AwfulThreadTagLoader.emptyThreadTagImage()
            tagImageName = thread.threadTag?.imageName
            
            let rating = lroundf(thread.rating).clamp(0...5)
            if rating > 0 && (AwfulForumTweaks(forumID: thread.forum?.forumID)?.showRatings ?? true) {
                ratingImage = UIImage(named: "rating\(rating)")
            }
            
            if let secondaryImageName = thread.secondaryThreadTag?.imageName {
                secondaryTagImage = AwfulThreadTagLoader.imageNamed(secondaryImageName)
            }
            
            tagAndRatingAlpha = appearsClosed ? 0.5 : 1
        } else {
            missingTagImage = nil
            tagImageName = nil
            tagAndRatingAlpha = 1
        }
        
        separatorColor = theme["listSeparator"]
        backgroundColor = theme["listBackground"]
    }
}

private protocol ThemeProvider {
    var theme: AwfulTheme! { get }
}

extension NewThreadListViewController: ThemeProvider {}

private final class NewBookmarksDataSource: NSObject, ASTableViewDataSource, NSFetchedResultsControllerDelegate {
    private let tableView: UITableView
    private let themeProvider: ThemeProvider
    var isEmpty: Bool { return controller.fetchedObjects?.isEmpty ?? true }
    
    lazy var controller: NSFetchedResultsController = { [unowned self] in
        let fetchRequest = NSFetchRequest(entityName: Thread.entityName())
        fetchRequest.predicate = NSPredicate(format: "bookmarked = YES AND bookmarkListPage > 0")
        var sortDescriptors = [NSSortDescriptor(key: "bookmarkListPage", ascending: true)]
        if AwfulSettings.sharedSettings().threadsSortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchBatchSize = 20
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: AwfulAppDelegate.instance().managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        var error: NSError?
        if !controller.performFetch(&error) {
            fatalError("initial fetch failed: \(error)")
        }
        
        controller.delegate = self
        return controller
        }()
    
    init(tableView: UITableView, themeProvider: ThemeProvider) {
        self.tableView = tableView
        self.themeProvider = themeProvider
        super.init()
    }
    
    subscript(indexPath: NSIndexPath) -> Thread {
        return controller.objectAtIndexPath(indexPath) as Thread
    }
    
    private func viewModelForThreadAtIndexPath(indexPath: NSIndexPath) -> ThreadViewModel {
        var viewModel: ThreadViewModel!
        controller.managedObjectContext.performBlockAndWait {
            let thread = self[indexPath]
            viewModel = ThreadViewModel(thread: thread, theme: self.themeProvider.theme)
        }
        return viewModel
    }
    
    // MARK: ASTableViewDataSource
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        let info = controller.sections!.first as NSFetchedResultsSectionInfo
        return info.numberOfObjects
    }
    
    func tableView(tableView: ASTableView, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode {
        let node = ThreadCellNode()
        node.viewModel = viewModelForThreadAtIndexPath(indexPath)
        return node
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    private func controllerDidChangeContent(controller: NSFetchedResultsController) {
        // TODO once ASTableView can handle beginUpdates/endUpdates, do that instead
        tableView.reloadData()
    }
}
