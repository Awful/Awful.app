//  NewThreadListViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class NewThreadListViewController: AwfulViewController, ASTableViewDelegate {
    private let tableView: ASTableView
    private var refreshControl: UIRefreshControl!
    private lazy var dataSource: NewBookmarksDataSource = { [unowned self] in
        return NewBookmarksDataSource(themeProvider: self) }()
    
    override init() {
        tableView = ASTableView()
        super.init(nibName: nil, bundle: nil)
        
        tableView.asyncDataSource = dataSource
        tableView.asyncDelegate = self
        
        title = "Bookmarks"
        tabBarItem.image = UIImage(named: "bookmarks")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func refresh(sender: UIRefreshControl?) {
        AwfulForumsClient.sharedClient().listBookmarkedThreadsOnPage(1) { [weak self] error, threads in
            if error != nil && self?.visible == true {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
            
            sender?.endRefreshing()
            return
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
    
    override func loadView() {
        KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.threadsSortedByUnread, options: nil) { [unowned self] _, _, _ in
            self.dataSource = NewBookmarksDataSource(themeProvider: self)
            self.tableView.asyncDataSource = self.dataSource
            self.tableView.reloadData()
        }
        KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.showThreadTags, options: nil) { [unowned self] _, _, _ in
            self.tableView.reloadData()
        }
        
        // HACK: UIRefreshControl is only documented to work with UITableViewController. Expect this to break at any time.
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
        
        tableView.separatorStyle = .None
        
        view = tableView
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        tableView.reloadData()
        refreshControl.tintColor = theme["listTextColor"] as? UIColor
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
    private var tagPadding: UIEdgeInsets { return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8) }
    private var bottomLinePadding: UIEdgeInsets { return UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0) }
    private var unreadPostsPadding: UIEdgeInsets { return UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0) }
    
    private var titlePadding = UIEdgeInsetsZero
    
    override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
        let availableSize = constrainedSize.sizeByInsetting(outerInsets)
        let leftSize = tagAndRatingNode.measure(availableSize)
        let rightSize = unreadPostsNode.measure(availableSize)
        titlePadding = UIEdgeInsets(
            left: leftSize.width > 0 ? tagPadding.right : 0,
            right: rightSize.width > 0 ? unreadPostsPadding.left : 0)
        
        let availableMiddleWidth = availableSize.width - leftSize.width - rightSize.width - titlePadding.horizontal
        let titleSize = titleNode.measure(CGSize(width: availableMiddleWidth, height: constrainedSize.height))
        let bottomLineSize = bottomLineNode.measure(CGSize(width: availableMiddleWidth, height: constrainedSize.height))
        
        let middleHeight = titleSize.height + bottomLineSize.height + bottomLinePadding.top
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
        let combinedTextSize = CGSize(width: middlePart.width, height: titleSize.height + bottomLineSize.height + bottomLinePadding.top)
        let combinedTextFrame = CGRect(size: combinedTextSize, centeredInRect: middlePart)
        let (titleFrame, bottomLineFrame) = combinedTextFrame.rectsByDividing(titleSize.height, fromEdge: .MinYEdge, withGap: bottomLinePadding.top)
        titleNode.frame = titleFrame
        bottomLineNode.frame = bottomLineFrame
        
        unreadPostsNode.frame = CGRect(size: rightSize, centeredInRect: rightPart)
        
        let pixelHeight = 1 / UIScreen.mainScreen().scale
        separator.frame = CGRect(x: CGRectGetMinX(titleNode.frame), y: bounds.height - pixelHeight, width: bounds.width, height: pixelHeight)
    }
    
    private final class TagAndRatingNode: ASDisplayNode {
        private let tagNode = ThreadTagNode()
        private let ratingNode = ASImageNode()
        
        override init() {
            super.init()
            addSubnode(tagNode)
            addSubnode(ratingNode)
        }
        
        func setTagImageName(tagImageName: String?, placeholderImage: UIImage?) {
            tagNode.missingTagImage = placeholderImage
            tagNode.tagImageName = tagImageName
        }
        
        var ratingImage: UIImage? {
            get {
                return ratingNode.image
            }
            set {
                ratingNode.image = newValue
            }
        }
        
        private var padding: CGFloat { return 2 }
        
        private override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
            let tagSize = tagNode.measure(constrainedSize)
            let ratingSize = ratingNode.measure(constrainedSize)
            if ratingSize.isEmpty {
                return tagSize
            } else {
                return CGSize(
                    width: max(tagSize.width, ratingSize.width),
                    height: tagSize.height + ratingSize.height + padding)
            }
        }
        
        private override func layout() {
            tagNode.frame = CGRect(size: tagNode.calculatedSize, centeredInRect: bounds)
            let ratingSize = ratingNode.calculatedSize
            ratingNode.frame = CGRect(size: ratingSize, centeredInRect: bounds)
            if !ratingSize.isEmpty {
                tagNode.frame.origin.y = 0
                ratingNode.frame.origin.y = bounds.maxY - ratingSize.height
            }
        }
    }
}

private struct ThreadViewModel {
    let theme: AwfulTheme
    let title: String
    let titleFont: UIFont
    var bottomLine: String { return "\(numberOfPages) pages. \(killedBy)" }
    let bottomLineFont: UIFont
    private let numberOfPages: String
    private let killedBy: String
    let unreadPosts: String
    let unreadPostsFont: UIFont
    let unreadPostsColor: UIColor
    let missingTagImage: UIImage?
    let tagImageName: String?
    let ratingImage: UIImage?
    
    init(thread: Thread, theme: AwfulTheme) {
        self.theme = theme
        title = thread.title ?? ""
        numberOfPages = "\(thread.numberOfPages)"
        if thread.beenSeen {
            let lastPoster = thread.lastPostAuthorName ?? ""
            killedBy = "Killed by \(lastPoster)"
        } else {
            let author = thread.author?.username ?? ""
            killedBy = "Posted by \(author)"
        }
        
        unreadPosts = thread.beenSeen ? "\(thread.unreadPosts)" : ""
        unreadPostsColor = {
            if thread.unreadPosts > 0 {
                switch (thread.starCategory) {
                case .Orange: return theme["unreadBadgeOrangeColor"] as UIColor?
                case .Red: return theme["unreadBadgeRedColor"] as UIColor?
                case .Yellow: return theme["unreadBadgeYellowColor"] as UIColor?
                case .None: return theme["tintColor"] as UIColor?
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
        } else {
            missingTagImage = nil
            tagImageName = nil
        }
    }
    
    var titleColor: UIColor {
        return theme["listTextColor"] as UIColor? ?? UIColor.blackColor()
    }
    
    var bottomLineTextColor: UIColor {
        return theme["listSecondaryTextColor"] as UIColor? ?? UIColor.darkGrayColor()
    }
    
    var separatorColor: UIColor? {
        return theme["listSeparatorColor"] as UIColor?
    }
    
    var backgroundColor: UIColor? {
        return theme["listBackgroundColor"] as UIColor?
    }
}

private protocol ThemeProvider {
    var theme: AwfulTheme! { get }
}

extension NewThreadListViewController: ThemeProvider {}

private final class NewBookmarksDataSource: NSObject, ASTableViewDataSource, NSFetchedResultsControllerDelegate {
    private let themeProvider: ThemeProvider
    var theme: AwfulTheme { return themeProvider.theme }
    
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
    
    init(themeProvider: ThemeProvider) {
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
            viewModel = ThreadViewModel(thread: thread, theme: self.theme)
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
        // TODO something useful
    }
}