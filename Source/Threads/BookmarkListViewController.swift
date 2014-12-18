//  BookmarkListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A list of bookmarked threads.
// The @objc name here is for state restoration purposes. I'm not trying to be confusing :-)
@objc(BookmarkedThreadListViewController)
final class BookmarkListViewController: ThreadListViewController {
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
        
        title = "Bookmarks"
        tabBarItem.image = UIImage(named: "bookmarks")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeNewDataSource() {
        let dataSource = BookmarkDataSource(managedObjectContext: managedObjectContext)
        dataSource.deletionDelegate = self
        self.dataSource = dataSource
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        self.refreshControl = refreshControl
        
        tableView.addInfiniteScrollingWithActionHandler { [unowned self] in
            self.loadPage(self.mostRecentlyLoadedPage + 1)
        }
        tableView.showsInfiniteScrolling = false
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshIfNecessary()
        
        let userActivity = NSUserActivity(activityType: Handoff.ActivityTypeListingThreads)
        userActivity.needsSave = true
        self.userActivity = userActivity
        
        becomeFirstResponder()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        resignFirstResponder()
        undoManager.removeAllActions()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }
    
    private func refreshIfNecessary() {
        if !AwfulForumsClient.sharedClient().reachable { return }
        
        if tableView.numberOfRowsInSection(0) == 0 || AwfulRefreshMinder.sharedMinder().shouldRefreshBookmarks() {
            refresh()
        }
    }
    
    @objc private func refresh() {
        refreshControl?.beginRefreshing()
        loadPage(1)
    }
    
    private func loadPage(page: Int) {
        AwfulForumsClient.sharedClient().listBookmarkedThreadsOnPage(page) { [weak self] (error, threads) in
            if let error = error {
                if self?.visible == true {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    self?.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                AwfulRefreshMinder.sharedMinder().didFinishRefreshingBookmarks()
                self?.mostRecentlyLoadedPage = page
            }
            
            self?.refreshControl?.endRefreshing()
            self?.tableView.infiniteScrollingView?.stopAnimating()
            self?.tableView.showsInfiniteScrolling = threads.count >= 40
        }
    }
    
    private var mostRecentlyLoadedPage = 0
    
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
    
    @objc private func setThread(thread: Thread, isBookmarked: Bool) {
        let indexPath = dataSource.indexPathsForItem(thread)[0]
        undoManager.prepareWithInvocationTarget(self).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName(dataSource.tableView?(tableView, titleForDeleteConfirmationButtonForRowAtIndexPath: indexPath) ?? "")
        
        thread.bookmarked = false
        AwfulForumsClient.sharedClient().setThread(thread, isBookmarked: isBookmarked) { [weak self] error in
            if let error = error {
                thread.bookmarked = !isBookmarked
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    override func updateUserActivityState(activity: NSUserActivity) {
        activity.title = "Bookmarked Threads"
        activity.addUserInfoEntriesFromDictionary([Handoff.InfoBookmarksKey: true])
        activity.webpageURL = NSURL(string: "/bookmarkthreads.php", relativeToURL: AwfulForumsClient.sharedClient().baseURL)
    }
}

private protocol DeletesBookmarkedThreads: class {
    func setThread(thread: Thread, isBookmarked: Bool)
}

extension BookmarkListViewController: DeletesBookmarkedThreads {}

final class BookmarkDataSource: ThreadDataSource {
    private weak var deletionDelegate: DeletesBookmarkedThreads?
    
    init(managedObjectContext: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest(entityName: Thread.entityName())
        fetchRequest.predicate = NSPredicate(format: "bookmarked = YES AND bookmarkListPage > 0")
        var sortDescriptors = [NSSortDescriptor(key: "bookmarkListPage", ascending: true)]
        if AwfulSettings.sharedSettings().threadsSortedByUnread {
            sortDescriptors.append(NSSortDescriptor(key: "anyUnreadPosts", ascending: false))
        }
        sortDescriptors.append(NSSortDescriptor(key: "lastPostDate", ascending: false))
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchBatchSize = 20
        super.init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil)
    }
    
    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String {
        return "Remove"
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let thread = itemAtIndexPath(indexPath) as Thread
            deletionDelegate?.setThread(thread, isBookmarked: false)
        }
    }
}
