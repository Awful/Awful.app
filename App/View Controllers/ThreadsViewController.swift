//  ThreadsViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class ThreadsViewController: AwfulTableViewController, AwfulComposeTextViewControllerDelegate, AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration {
    let forum: Forum
    private var latestPage = 0
    
    private var filterThreadTag: ThreadTag?
    
    private var dataManager: ThreadDataManager {
        didSet {
            tableViewAdapter = nil
            
            if isViewLoaded() {
                createTableViewAdapter()
                
                tableView.reloadData()
            }
        }
    }
    
    private var tableViewAdapter: ThreadDataManagerTableViewAdapter!
    
    init(forum: Forum) {
        self.forum = forum
        dataManager = ThreadDataManager(forum: forum, filterThreadTag: filterThreadTag)
        
        super.init(style: .Plain)
        
        title = forum.name
        
        navigationItem.rightBarButtonItem = composeBarButtonItem
        updateComposeBarButtonItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum)
    }
    
    private func createTableViewAdapter() {
        tableViewAdapter = ThreadDataManagerTableViewAdapter(tableView: tableView, dataManager: dataManager, ignoreSticky: false, cellConfigurationHandler: { [weak self] cell, viewModel in
            cell.viewModel = viewModel
            cell.longPressAction = self?.didLongPressCell
            // TODO: Bring back thread tag update observation. (should probably do it as a reload and track it by thread)
        })
        
        dataManager.delegate = tableViewAdapter
        tableView.dataSource = tableViewAdapter
    }
    
    private func loadPage(page: Int) {
        AwfulForumsClient.sharedClient().listThreadsInForum(forum, withThreadTag: filterThreadTag, onPage: page) { [weak self] error, threads in
            if let error = error where self?.visible == true {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
            
            if error == .None {
                self?.latestPage = page
                
                self?.scrollToLoadMoreBlock = self!.loadNextPage
                
                self?.tableView.tableHeaderView = self!.filterButton
                
                if let forum = self?.forum where self?.filterThreadTag == nil {
                    AwfulRefreshMinder.sharedMinder().didFinishRefreshingForum(forum)
                } else if let forum = self?.forum {
                    AwfulRefreshMinder.sharedMinder().didFinishRefreshingFilteredForum(forum)
                }
                    
                self?.updateComposeBarButtonItem()
            }
            
            self?.refreshControl?.endRefreshing()
            self?.infiniteScrollController.stop()
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerNib(UINib(nibName: ThreadTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ThreadTableViewCell.identifier)
        
        tableView.estimatedRowHeight = ThreadTableViewCell.estimatedRowHeight
        tableView.restorationIdentifier = "Threads table view"
        tableView.separatorStyle = .None
        
        createTableViewAdapter()
        
        pullToRefreshBlock = self.refresh
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "settingsDidChange:", name: AwfulSettingsDidChangeNotification, object: nil)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        updateFilterButton()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // TODO: enable infinite scroll so long as the table is nonempty (people want this even though I think it's confusing).
        // TODO: show filter button if table is nonempty
        
        prepareUserActivity()
        
        if AwfulForumsClient.sharedClient().reachable &&
            // TODO: basically the next line
            // (dataSource.numberOfSections > 0 && dataSource.tableView(tableView, numberOfRowsInSection: 0) > 0) &&
            ((filterThreadTag == nil && AwfulRefreshMinder.sharedMinder().shouldRefreshForum(forum)) ||
                (filterThreadTag != nil && AwfulRefreshMinder.sharedMinder().shouldRefreshFilteredForum(forum)))
        {
            refresh()
            
            if let refreshControl = refreshControl {
                tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.bounds.height), animated: true)
            }
        }
    }
    
    // MARK: Actions and notifications
    
    private func didLongPressCell(cell: ThreadTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let thread = dataManager.threads[indexPath.row]
        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] sourceRect, sourceView in
            if let
                row = self?.dataManager.threads.indexOf(thread),
                cell = self?.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row, inSection: 0))
            {
                sourceRect.memory = cell.bounds
                sourceView.memory = cell
            }
        }
        presentViewController(actionViewController, animated: true, completion: nil)
    }
    
    private func loadNextPage() {
        loadPage(latestPage + 1)
    }
    
    private func refresh() {
        refreshControl?.beginRefreshing()
        
        loadPage(1)
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }

        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() where isViewLoaded():
            createTableViewAdapter()
            tableView.reloadData()
            
        case AwfulSettingsKeys.forumThreadsSortedByUnread.takeUnretainedValue():
            dataManager = ThreadDataManager(forum: forum, filterThreadTag: filterThreadTag)
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() where visible:
            prepareUserActivity()
            
        default:
            break
        }
    }
    
    // MARK: Composition
    
    private lazy var composeBarButtonItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .Plain, target: self, action: "didTapCompose:")
        item.accessibilityLabel = "New thread"
        return item
        }()
    
    private lazy var threadComposeViewController: ThreadComposeViewController! = { [unowned self] in
        let composeViewController = ThreadComposeViewController(forum: self.forum)
        composeViewController.restorationIdentifier = "New thread composition"
        composeViewController.delegate = self
        return composeViewController
        }()
    
    private func updateComposeBarButtonItem() {
        composeBarButtonItem.enabled = forum.canPost && forum.lastRefresh != nil
    }
    
    private func didTapCompose() {
        presentViewController(threadComposeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: AwfulComposeTextViewControllerDelegate
    
    func composeTextViewController(composeTextViewController: ComposeTextViewController!, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft keepDraft: Bool) {
        dismissViewControllerAnimated(true) {
            if let thread = self.threadComposeViewController.thread where success {
                let postsPage = PostsPageViewController(thread: thread)
                postsPage.restorationIdentifier = "Posts"
                postsPage.loadPage(1, updatingCache: true)
                self.showDetailViewController(postsPage, sender: self)
            }
            
            if !keepDraft {
                self.threadComposeViewController = nil
            }
        }
    }
    
    // MARK: Filtering by tag
    
    private lazy var filterButton: UIButton = { [unowned self] in
        let button = UIButton(type: .System)
        button.bounds.size.height = button.intrinsicContentSize().height + 8
        button.addTarget(self, action: "didTapFilterButton:", forControlEvents: .TouchUpInside)
        return button
        }()
    
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
    
    @objc private func didTapFilterButton(sender: UIButton) {
        let imageName = filterThreadTag?.imageName ?? AwfulThreadTagLoaderNoFilterImageName
        threadTagPicker.selectImageName(imageName)
        threadTagPicker.presentFromView(sender)
    }
    
    private func updateFilterButton() {
        let title = filterThreadTag == nil ? "Filter By Tag" : "Change Filter"
        filterButton.setTitle(title, forState: .Normal)
        
        filterButton.tintColor = theme["tintColor"]
    }
    
    // MARK: AwfulThreadTagPickerControllerDelegate
    
    func threadTagPicker(picker: AwfulThreadTagPickerController, didSelectImageName imageName: String) {
        if imageName == AwfulThreadTagLoaderNoFilterImageName {
            filterThreadTag = nil
        } else {
            filterThreadTag = forum.threadTags.array.first { ($0 as! ThreadTag).imageName == imageName } as! ThreadTag?
        }
        
        AwfulRefreshMinder.sharedMinder().forgetForum(forum)
        updateFilterButton()
        
        dataManager = ThreadDataManager(forum: forum, filterThreadTag: filterThreadTag)
        
        picker.dismiss()
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard AwfulSettings.sharedSettings().handoffEnabled else {
            userActivity = nil
            return
        }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityTypeListingThreads)
        activity.needsSave = true
        userActivity = activity
    }
    
    override func updateUserActivityState(activity: NSUserActivity) {
        activity.title = forum.name
        activity.addUserInfoEntriesFromDictionary([Handoff.InfoForumIDKey: forum.forumID])
        activity.webpageURL = NSURL(string: "http://forums.somethingawful.com/forumdisplay.php?forumid=\(forum.forumID)")
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataManager.threads[indexPath.row]
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.NextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let cell = cell as! ThreadTableViewCell
        let thread = dataManager.threads[indexPath.row]
        cell.themeData = ThreadTableViewCell.ThemeData(theme: theme, thread: thread)
    }
    
    // MARK: UIViewControllerRestoration
    
    class func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        var forumKey = coder.decodeObjectForKey(RestorationKeys.forumKey) as! ForumKey!
        if forumKey == nil {
            guard let forumID = coder.decodeObjectForKey(ObsoleteRestorationKeys.forumID) as? String else { return nil }
            forumKey = ForumKey(forumID: forumID)
        }
        let managedObjectContext = AwfulAppDelegate.instance().managedObjectContext
        let forum = Forum.objectForKey(forumKey, inManagedObjectContext: managedObjectContext) as! Forum
        let viewController = self.init(forum: forum)
        viewController.restorationIdentifier = identifierComponents.last as! String?
        viewController.restorationClass = self
        return viewController
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(forum.objectKey, forKey: RestorationKeys.forumKey)
        coder.encodeObject(threadComposeViewController, forKey: RestorationKeys.newThreadViewController)
        coder.encodeObject(filterThreadTag?.objectKey, forKey: RestorationKeys.filterThreadTagKey)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        if let compose = coder.decodeObjectForKey(RestorationKeys.newThreadViewController) as? ThreadComposeViewController {
            compose.delegate = self
            threadComposeViewController = compose
        }
        
        var tagKey = coder.decodeObjectForKey(RestorationKeys.filterThreadTagKey) as! ThreadTagKey?
        if tagKey == nil {
            if let tagID = coder.decodeObjectForKey(ObsoleteRestorationKeys.filterThreadTagID) as? String {
                tagKey = ThreadTagKey(imageName: nil, threadTagID: tagID)
            }
        }
        if let tagKey = tagKey {
            filterThreadTag = ThreadTag.objectForKey(tagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        updateFilterButton()
    }
    
    private struct RestorationKeys {
        static let forumKey = "ForumKey"
        static let newThreadViewController = "AwfulNewThreadViewController"
        static let filterThreadTagKey = "FilterThreadTagKey"
    }
    
    private struct ObsoleteRestorationKeys {
        static let forumID = "AwfulForumID"
        static let filterThreadTagID = "AwfulFilterThreadTagID"
    }
}

private extension ThreadDataManager {
    convenience init(forum: Forum, filterThreadTag: ThreadTag?) {
        let fetchRequest = NSFetchRequest(entityName: Thread.entityName())
        fetchRequest.fetchBatchSize = 20
        
        let basePredicate = NSPredicate(format: "threadListPage > 0 AND forum == %@", forum)
        if let threadTag = filterThreadTag {
            let morePredicate = NSPredicate(format: "threadTag == %@", threadTag)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, morePredicate])
        } else {
            fetchRequest.predicate = basePredicate
        }
        
        var sortDescriptors = [
            NSSortDescriptor(key: "stickyIndex", ascending: true),
            NSSortDescriptor(key: "threadListPage", ascending: true)]
        if AwfulSettings.sharedSettings().forumThreadsSortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        
        self.init(managedObjectContext: forum.managedObjectContext!, fetchRequest: fetchRequest)
    }
}
