//  BookmarksViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

// TODO: State preservation and restoration
final class BookmarksViewController: AwfulTableViewController, BookmarksDataManagerDelegate {
    private var latestPage = 0
    private let managedObjectContext: NSManagedObjectContext
    private var dataManager: BookmarksDataManager {
        didSet {
            dataManager.delegate = self
            
            if isViewLoaded() {
                tableView.reloadData()
            }
        }
    }
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        dataManager = BookmarksDataManager(managedObjectContext: managedObjectContext)
        
        super.init(style: .Plain)
        
        dataManager.delegate = self
        
        title = "Bookmarks"
        
        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func loadPage(page: Int) {
        AwfulForumsClient.sharedClient().listBookmarkedThreadsOnPage(page) { [weak self] error, threads in
            if let error = error where self?.visible == true {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
            
            if error == .None {
                self?.latestPage = page
                
                AwfulRefreshMinder.sharedMinder().didFinishRefreshingBookmarks()
            }
            
            self?.refreshControl?.endRefreshing()
            self?.infiniteScrollController?.stop()
            
            self?.scrollToLoadMoreBlock = threads?.count >= 40 ? self!.loadMore : nil
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerNib(UINib(nibName: ThreadTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ThreadTableViewCell.identifier)
        
        tableView.estimatedRowHeight = ThreadTableViewCell.estimatedRowHeight
        tableView.separatorStyle = .None
        
        pullToRefreshBlock = refresh
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "settingsDidChange:", name: AwfulSettingsDidChangeNotification, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        prepareUserActivity()
        
        // TODO: enable infinite scroll so long as the table is nonempty (people want this even though I think it's confusing).
        
        becomeFirstResponder()
        
        if AwfulForumsClient.sharedClient().reachable && AwfulRefreshMinder.sharedMinder().shouldRefreshBookmarks() {
            refresh()
            
            if let refreshControl = refreshControl {
                tableView.setContentOffset(CGPoint(x: 0, y: -refreshControl.bounds.height), animated: true)
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        undoManager.removeAllActions()
        
        resignFirstResponder()
    }
    
    // MARK: Actions and notifications
    
    @objc private func didLongPressCell(sender: UILongPressGestureRecognizer) {
        let cell = sender.view as! UITableViewCell
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
    
    private func loadMore() {
        loadPage(latestPage + 1)
    }
    
    private func refresh() {
        refreshControl?.beginRefreshing()
        loadPage(1)
    }
    
    @objc private func setThread(thread: Thread, isBookmarked: Bool) {
        undoManager.prepareWithInvocationTarget(self).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = false
        AwfulForumsClient.sharedClient().setThread(thread, isBookmarked: isBookmarked) { [weak self] error in
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        
        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() where isViewLoaded():
            tableView.reloadData()
            
        case AwfulSettingsKeys.bookmarksSortedByUnread.takeUnretainedValue():
            dataManager = BookmarksDataManager(managedObjectContext: managedObjectContext)
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() where visible:
            prepareUserActivity()
            
        default:
            break
        }
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
        activity.title = "Bookmarked Threads"
        activity.addUserInfoEntriesFromDictionary([Handoff.InfoBookmarksKey: true])
        activity.webpageURL = NSURL(string: "/bookmarkthreads.php", relativeToURL: AwfulForumsClient.sharedClient().baseURL)
    }
    
    // MARK: Undo
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override var undoManager: NSUndoManager {
        return _undoManager
    }
    
    private let _undoManager: NSUndoManager = {
        let undoManager = NSUndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
        }()
    
    // MARK: UITableViewDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataManager.threads.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ThreadTableViewCell.identifier, forIndexPath: indexPath) as! ThreadTableViewCell
        let thread = dataManager.threads[indexPath.row]
        
        cell.viewModel = ThreadTableViewCell.ViewModel(thread: thread, showsTag: AwfulSettings.sharedSettings().showThreadTags, overrideSticky: false)
        
        // TODO: Bring back thread tag update observation. (should probably do it as a reload and track it by thread)
        
        cell.longPress.removeTarget(self, action: nil)
        cell.longPress.addTarget(self, action: "didLongPressCell:")
        
        return cell;
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataManager.threads[indexPath.row]
        setThread(thread, isBookmarked: false)
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
    
    // MARK: BookmarksDataManagerDelegate
    
    private func dataManagerWillChangeContent(dataManager: BookmarksDataManager) {
        tableView.beginUpdates()
    }
    
    private func dataManager(dataManager: BookmarksDataManager, didInsertRowAtIndexPath indexPath: NSIndexPath) {
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    private func dataManager(dataManager: BookmarksDataManager, didDeleteRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }

    private func dataManager(dataManager: BookmarksDataManager, didMoveRowAtIndexPath fromIndexPath: NSIndexPath, toRowAtIndexPath toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    private func dataManager(dataManager: BookmarksDataManager, didUpdateRowAtIndexPath indexPath: NSIndexPath) {
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }

    private func dataManagerDidChangeContent(dataManager: BookmarksDataManager) {
        tableView.endUpdates()
    }
}

private class BookmarksDataManager: NSObject, NSFetchedResultsControllerDelegate {
    var threads: [Thread] {
        return resultsController.fetchedObjects as! [Thread]
    }
    var delegate: BookmarksDataManagerDelegate?
    
    private let resultsController: NSFetchedResultsController
    
    init(managedObjectContext: NSManagedObjectContext, sortedByUnread: Bool) {
        let fetchRequest = NSFetchRequest(entityName: Thread.entityName())
        fetchRequest.fetchBatchSize = 20
        fetchRequest.predicate = NSPredicate(format: "bookmarked = YES AND bookmarkListPage > 0")
        
        var sortDescriptors = [NSSortDescriptor(key: "bookmarkListPage", ascending: true)]
        if sortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors

        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init()
        
        resultsController.delegate = self
        try! resultsController.performFetch()
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    @objc private func controllerWillChangeContent(controller: NSFetchedResultsController) {
        delegate?.dataManagerWillChangeContent(self)
    }
    
    @objc private func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            delegate?.dataManager(self, didInsertRowAtIndexPath: newIndexPath!)
        case .Delete:
            delegate?.dataManager(self, didDeleteRowAtIndexPath: indexPath!)
        case .Move:
            delegate?.dataManager(self, didMoveRowAtIndexPath: indexPath!, toRowAtIndexPath: newIndexPath!)
        case .Update:
            delegate?.dataManager(self, didUpdateRowAtIndexPath: indexPath!)
        }
    }
    
    @objc private func controllerDidChangeContent(controller: NSFetchedResultsController) {
        delegate?.dataManagerDidChangeContent(self)
    }
}

/// Separates the dependency on AwfulSettings.sharedSettings.
extension BookmarksDataManager {
    convenience init(managedObjectContext: NSManagedObjectContext) {
        self.init(managedObjectContext: managedObjectContext, sortedByUnread: AwfulSettings.sharedSettings().bookmarksSortedByUnread)
    }
}

private protocol BookmarksDataManagerDelegate {
    func dataManagerWillChangeContent(dataManager: BookmarksDataManager)
    func dataManager(dataManager: BookmarksDataManager, didInsertRowAtIndexPath indexPath: NSIndexPath)
    func dataManager(dataManager: BookmarksDataManager, didDeleteRowAtIndexPath indexPath: NSIndexPath)
    func dataManager(dataManager: BookmarksDataManager, didMoveRowAtIndexPath fromIndexPath: NSIndexPath, toRowAtIndexPath toIndexPath: NSIndexPath)
    func dataManager(dataManager: BookmarksDataManager, didUpdateRowAtIndexPath indexPath: NSIndexPath)
    func dataManagerDidChangeContent(dataManager: BookmarksDataManager)
}

// TODO: extract to separate file
extension InAppActionViewController {
    convenience init(thread: Thread, presentingViewController viewController: UIViewController) {
        self.init()
        
        var items = [AwfulIconActionItem]()
        
        func jumpToPageItem(itemType: AwfulIconActionItemType) -> AwfulIconActionItem {
            return AwfulIconActionItem(type: itemType) {
                let postsViewController = PostsPageViewController(thread: thread)
                postsViewController.restorationIdentifier = "Posts"
                let page = itemType == .JumpToLastPage ? AwfulThreadPage.Last.rawValue : 1
                postsViewController.loadPage(page, updatingCache: true)
                viewController.showDetailViewController(postsViewController, sender: self)
            }
        }
        items.append(jumpToPageItem(.JumpToFirstPage))
        items.append(jumpToPageItem(.JumpToLastPage))
        
        let bookmarkItemType: AwfulIconActionItemType = thread.bookmarked ? .RemoveBookmark : .AddBookmark
        items.append(AwfulIconActionItem(type: bookmarkItemType) { [weak viewController] in
            AwfulForumsClient.sharedClient().setThread(thread, isBookmarked: !thread.bookmarked) { error in
                if let error = error {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    viewController?.presentViewController(alert, animated: true, completion: nil)
                }
            }
            return // hooray for implicit return
            })
        
        if let author = thread.author {
            items.append(AwfulIconActionItem(type: .UserProfile) {
                let profile = ProfileViewController(user: author)
                if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                    viewController.presentViewController(profile.enclosingNavigationController, animated: true, completion: nil)
                } else {
                    viewController.navigationController?.pushViewController(profile, animated: true)
                }
                })
        }
        
        items.append(AwfulIconActionItem(type: .CopyURL) {
            if let URL = NSURL(string: "http://forums.somethingawful.com/showthread.php?threadid=\(thread.threadID)") {
                AwfulSettings.sharedSettings().lastOfferedPasteboardURL = URL.absoluteString
                UIPasteboard.generalPasteboard().awful_URL = URL
            }
            })
        
        if thread.beenSeen {
            items.append(AwfulIconActionItem(type: .MarkAsUnread) { [weak viewController] in
                let oldSeen = thread.seenPosts
                thread.seenPosts = 0
                AwfulForumsClient.sharedClient().markThreadUnread(thread) { error in
                    if let error = error {
                        if thread.seenPosts == 0 {
                            thread.seenPosts = oldSeen
                        }
                        let alert = UIAlertController(networkError: error, handler: nil)
                        viewController?.presentViewController(alert, animated: true, completion: nil)
                    }
                }
                })
        }
        
        self.items = items
    }
}
