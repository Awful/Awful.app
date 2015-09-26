//  ForumSpecificThreadListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app/

final class ForumSpecificThreadListViewController: ThreadListViewController {
    let forum: Forum
    private var threadTag: ThreadTag?
    
    init(forum: Forum) {
        self.forum = forum
        super.init()
        
        forum.addObserver(self, forKeyPath: "name", options: .Initial, context: &KVOContext)
        navigationItem.rightBarButtonItem = newThreadItem
        updateNewThreadItemEnabled()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        forum.removeObserver(self, forKeyPath: "name", context: &KVOContext)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override var sortByUnreadSettingsKey: String {
        return AwfulSettingsKeys.forumThreadsSortedByUnread.takeUnretainedValue() as String
    }
    
    override func makeNewDataSource() {
        dataSource = ForumSpecificThreadDataSource(forum: forum, filteredByThreadTag: threadTag)
    }
    
    private lazy var newThreadItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .Plain, target: self, action: "didTapNewThreadItem:")
        item.accessibilityLabel = "New thread"
        return item
        }()
    
    private func updateNewThreadItemEnabled() {
        newThreadItem.enabled = forum.lastRefresh != nil && forum.canPost
    }
    
    private var threadComposeViewController: ThreadComposeViewController?
    
    @objc private func didTapNewThreadItem(sender: UIBarButtonItem) {
        if threadComposeViewController == nil {
            let compose = ThreadComposeViewController(forum: forum)
            compose.restorationIdentifier = "New thread composition"
            compose.delegate = self
            threadComposeViewController = compose
        }
        if let compose = threadComposeViewController {
            presentViewController(compose.enclosingNavigationController, animated: true, completion: nil)
        }
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum)
    }
    
    private func refreshIfNecessary() {
        if !AwfulForumsClient.sharedClient().reachable {
            return
        }
        
        if dataSource.numberOfSections > 0 && dataSource.tableView(tableView, numberOfRowsInSection: 0) > 0 {
            return
        }
        
        if threadTag == nil && !AwfulRefreshMinder.sharedMinder().shouldRefreshForum(forum) {
            return
        } else if threadTag != nil && !AwfulRefreshMinder.sharedMinder().shouldRefreshFilteredForum(forum) {
            return
        }
        
        refresh()
        if let refreshControl = refreshControl {
            tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.bounds.height), animated: true)
        }
    }
    
    @objc private func refresh() {
        refreshControl?.beginRefreshing()
        loadPage(1)
    }
    
    private func loadPage(page: Int) {
        let forum = self.forum
        AwfulForumsClient.sharedClient().listThreadsInForum(forum, withThreadTag: threadTag, onPage: page) { [weak self] error, threads in
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            } else {
                if page == 1 {
                    self?.infiniteTableController.enabled = true
                }
                
                if self?.threadTag == nil {
                    AwfulRefreshMinder.sharedMinder().didFinishRefreshingForum(forum)
                } else {
                    AwfulRefreshMinder.sharedMinder().didFinishRefreshingFilteredForum(forum)
                }
                    
                self?.updateNewThreadItemEnabled()
            }
            
            self?.mostRecentlyLoadedPage = page
            self?.refreshControl?.endRefreshing()
            self?.infiniteTableController.stop()
        }
    }
    
    private var mostRecentlyLoadedPage: Int = 0
    
    private var justLoaded: Bool = false
    private lazy var filterButton: UIButton = { [unowned self] in
        let button = UIButton(type: .System) as UIButton
        button.frame.size.height = button.intrinsicContentSize().height + 8
        button.addTarget(self, action: "showFilterPicker:", forControlEvents: .TouchUpInside)
        return button
        }()
    
    private func updateFilterButtonText() {
        if threadTag == nil {
            filterButton.setTitle("Filter by tag", forState: .Normal)
        } else {
            filterButton.setTitle("Change filter", forState: .Normal)
        }
    }
    
    @objc private func showFilterPicker(sender: UIButton) {
        let imageName = threadTag?.imageName ?? AwfulThreadTagLoaderNoFilterImageName
        threadTagPicker.selectImageName(imageName)
        threadTagPicker.presentFromView(sender)
    }
    
    private lazy var threadTagPicker: AwfulThreadTagPickerController = { [unowned self] in
        let imageNames = self.forum.threadTags.array
            .filter { ($0 as! ThreadTag).imageName != nil }
            .map { ($0 as! ThreadTag).imageName! }
        let picker = AwfulThreadTagPickerController(imageNames: [AwfulThreadTagLoaderNoFilterImageName] + imageNames, secondaryImageNames: nil)
        picker.delegate = self
        picker.title = "Filter Threads"
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        return picker
        }()
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &KVOContext {
            if object as! NSObject == forum && keyPath == "name" {
                title = forum.name
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    @objc private func settingsDidChange(note: NSNotification) {
        if let key = note.userInfo?[AwfulSettingsDidChangeSettingKey] as? String {
            if key == AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() {
                if visible {
                    configureUserActivity()
                }
            }
        }
    }
    
    private func configureUserActivity() {
        if AwfulSettings.sharedSettings().handoffEnabled {
            let userActivity = NSUserActivity(activityType: Handoff.ActivityTypeListingThreads)
            userActivity.needsSave = true
            self.userActivity = userActivity
        }
    }
    
    override func updateUserActivityState(activity: NSUserActivity) {
        activity.title = forum.name
        activity.addUserInfoEntriesFromDictionary([Handoff.InfoForumIDKey: forum.forumID])
        activity.webpageURL = NSURL(string: "http://forums.somethingawful.com/forumdisplay.php?forumid=\(forum.forumID)")
    }
    
    private lazy var infiniteTableController: InfiniteTableController = { [unowned self] in
        let controller = InfiniteTableController(tableView: self.tableView) { [unowned self] in
            self.loadPage(self.mostRecentlyLoadedPage + 1)
        }
        controller.enabled = false
        return controller
        }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        self.refreshControl = refresh
        
        tableView.tableHeaderView = filterButton
        updateFilterButtonText()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "settingsDidChange:", name: AwfulSettingsDidChangeNotification, object: nil)
        
        justLoaded = true
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        filterButton.tintColor = theme["tintColor"]
        infiniteTableController.spinnerColor = theme["listTextColor"]
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if justLoaded {
            if let header = tableView.tableHeaderView {
                tableView.contentOffset = CGPoint(x: 0, y: header.bounds.height)
            }
            
            justLoaded = false
        }
        
        infiniteTableController.enabled = false
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        let visibleThreads = dataSource.numberOfSections > 0 ? dataSource.tableView(tableView, numberOfRowsInSection: 0) : 0
        infiniteTableController.enabled = mostRecentlyLoadedPage > 0 && visibleThreads > 0
        
        refreshIfNecessary()
        
        configureUserActivity()
    }
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        infiniteTableController.scrollViewDidScroll(scrollView)
    }
}

extension ForumSpecificThreadListViewController: AwfulComposeTextViewControllerDelegate {
    func composeTextViewController(composeTextViewController: ComposeTextViewController!, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft keepDraft: Bool) {
        dismissViewControllerAnimated(true) {
            if success {
                if let thread = self.threadComposeViewController?.thread {
                    let postsPage = PostsPageViewController(thread: thread)
                    postsPage.restorationIdentifier = "Posts"
                    postsPage.loadPage(1, updatingCache: true)
                    self.showDetailViewController(postsPage, sender: self)
                }
            }
            
            if !keepDraft {
                self.threadComposeViewController = nil
            }
        }
    }
}

extension ForumSpecificThreadListViewController: AwfulThreadTagPickerControllerDelegate {
    func threadTagPicker(picker: AwfulThreadTagPickerController, didSelectImageName imageName: String) {
        if imageName == AwfulThreadTagLoaderNoFilterImageName {
            threadTag = nil
        } else {
            threadTag = forum.threadTags.array.first { ($0 as! ThreadTag).imageName == imageName } as! ThreadTag?
        }
        
        AwfulRefreshMinder.sharedMinder().forgetForum(forum)
        updateFilterButtonText()
        
        makeNewDataSource()
        
        picker.dismiss()
    }
}

extension ForumSpecificThreadListViewController: UIViewControllerRestoration {
    class func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        var forumKey = coder.decodeObjectForKey(ForumKeyKey) as! ForumKey!
        if forumKey == nil {
            let forumID = coder.decodeObjectForKey(obsolete_ForumIDKey) as! String
            forumKey = ForumKey(forumID: forumID)
        }
        let managedObjectContext = AwfulAppDelegate.instance().managedObjectContext
        let forum = Forum.objectForKey(forumKey, inManagedObjectContext: managedObjectContext) as! Forum
        let viewController = ForumSpecificThreadListViewController(forum: forum)
        viewController.restorationIdentifier = identifierComponents.last as! String?
        viewController.restorationClass = self
        return viewController
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(forum.objectKey, forKey: ForumKeyKey)
        coder.encodeObject(threadComposeViewController, forKey: NewThreadViewControllerKey)
        coder.encodeObject(threadTag?.objectKey, forKey: FilterThreadTagKeyKey)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        if let compose = coder.decodeObjectForKey(NewThreadViewControllerKey) as? ThreadComposeViewController {
            compose.delegate = self
            threadComposeViewController = compose
        }
        
        var tagKey = coder.decodeObjectForKey(FilterThreadTagKeyKey) as! ThreadTagKey?
        if tagKey == nil {
            if let tagID = coder.decodeObjectForKey(obsolete_FilterThreadTagIDKey) as? String {
                tagKey = ThreadTagKey(imageName: nil, threadTagID: tagID)
            }
        }
        if let tagKey = tagKey {
            threadTag = ThreadTag.objectForKey(tagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        updateFilterButtonText()
    }
}

private let ForumKeyKey = "ForumKey"
private let obsolete_ForumIDKey = "AwfulForumID"
private let NewThreadViewControllerKey = "AwfulNewThreadViewController"
private let FilterThreadTagKeyKey = "FilterThreadTagKey"
private let obsolete_FilterThreadTagIDKey = "AwfulFilterThreadTagID"


final class ForumSpecificThreadDataSource: ThreadDataSource {
    init(forum: Forum, filteredByThreadTag threadTag: ThreadTag?) {
        let fetchRequest = NSFetchRequest(entityName: Thread.entityName())
        let basePredicate = NSPredicate(format: "threadListPage > 0 AND forum == %@", forum)
        if let threadTag = threadTag {
            let morePredicate = NSPredicate(format: "threadTag == %@", threadTag)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, morePredicate])
        } else {
            fetchRequest.predicate = basePredicate
        }
        var sortDescriptors = [NSSortDescriptor(key: "stickyIndex", ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: "threadListPage", ascending: true))
        if AwfulSettings.sharedSettings().forumThreadsSortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchBatchSize = 20
        super.init(fetchRequest: fetchRequest, managedObjectContext: forum.managedObjectContext!, sectionNameKeyPath: nil)
    }
}

private var KVOContext = 0
