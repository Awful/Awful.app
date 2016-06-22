//  BookmarksTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class BookmarksTableViewController: TableViewController, ThreadPeekPopControllerDelegate {
    private var latestPage = 0
    private let managedObjectContext: NSManagedObjectContext
    private var peekPopController: ThreadPeekPopController?
    
    private typealias DataManager = FetchedDataManager<Thread>
    
    private var dataManager: DataManager {
        didSet {
            tableViewAdapter = nil
            
            if isViewLoaded() {
                createTableViewAdapter()
                
                tableView.reloadData()
            }
        }
    }
    
    private var tableViewAdapter: ThreadDataManagerTableViewAdapter!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        let fetchRequest = Thread.bookmarksFetchRequest(sortedByUnread: AwfulSettings.sharedSettings().bookmarksSortedByUnread)
        dataManager = DataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
        
        super.init(style: .Plain)
        
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
    
    private func createTableViewAdapter() {
        tableViewAdapter = ThreadDataManagerTableViewAdapter(tableView: tableView, dataManager: dataManager, ignoreSticky: true, cellConfigurationHandler: { [weak self] cell, viewModel in
            cell.viewModel = viewModel
            cell.longPressAction = self?.didLongPressCell
        })
        tableViewAdapter.deletionHandler = { [weak self] thread in
            self?.setThread(thread, isBookmarked: false)
        }
        
        dataManager.delegate = tableViewAdapter
        tableView.dataSource = tableViewAdapter
    }
    
    private func loadPage(page: Int) {
        AwfulForumsClient.sharedClient().listBookmarkedThreadsOnPage(page) { [weak self] (error: NSError?, threads: [AnyObject]?) in
            if let error = error where self?.visible == true {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
            
            if error == .None {
                self?.latestPage = page
                
                RefreshMinder.sharedMinder.didRefresh(.Bookmarks)
            }
            
            self?.stopAnimatingPullToRefresh()
            self?.infiniteScrollController?.stop()
            
            self?.scrollToLoadMoreBlock = threads?.count >= 40 ? self!.loadMore : nil
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerNib(UINib(nibName: ThreadTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ThreadTableViewCell.identifier)
        
        tableView.estimatedRowHeight = ThreadTableViewCell.estimatedRowHeight
        tableView.restorationIdentifier = "Bookmarks table"
        tableView.separatorStyle = .None
        
        createTableViewAdapter()
        
        pullToRefreshBlock = refresh
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(BookmarksTableViewController.settingsDidChange(_:)), name: AwfulSettingsDidChangeNotification, object: nil)
        
        if traitCollection.forceTouchCapability == .Available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        prepareUserActivity()
        
        if !dataManager.contents.isEmpty {
            scrollToLoadMoreBlock = loadMore
        }
        
        becomeFirstResponder()
        
        if AwfulForumsClient.sharedClient().reachable &&
            (dataManager.contents.isEmpty || RefreshMinder.sharedMinder.shouldRefresh(.Bookmarks))
        {
            refresh()
            
            if let pullToRefreshView = tableView.pullToRefreshView {
                tableView.setContentOffset(CGPoint(x: 0, y: -pullToRefreshView.bounds.height), animated: true)
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        undoManager.removeAllActions()
        
        resignFirstResponder()
    }
    
    // MARK: Actions
    
    private func didLongPressCell(cell: ThreadTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let thread = dataManager.contents[indexPath.row]
        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] sourceRect, sourceView in
            if let
                row = self?.dataManager.contents.indexOf(thread),
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
        tableView.startPullToRefresh()
        loadPage(1)
    }
    
    // MARK: Notifications
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        
        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() where isViewLoaded():
            createTableViewAdapter()
            tableView.reloadData()
            
        case AwfulSettingsKeys.bookmarksSortedByUnread.takeUnretainedValue():
            let fetchRequest = Thread.bookmarksFetchRequest(sortedByUnread: AwfulSettings.sharedSettings().bookmarksSortedByUnread)
            dataManager = DataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
            
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
    
    // MARK: ThreadPeekPopControllerDelegate
    
    func threadForLocation(location: CGPoint) -> Thread? {
        guard let row = tableView.indexPathForRowAtPoint(location)?.row else {
            return nil
        }
        
        return dataManager.contents[row]
    }
    
    func viewForThread(thread: Thread) -> UIView? {
        guard let row = dataManager.contents.indexOf(thread) else {
            return nil
        }
        
        return tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row, inSection: 0))
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
    
    @objc private func setThread(thread: Thread, isBookmarked: Bool) {
        undoManager.prepareWithInvocationTarget(self).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = false
        AwfulForumsClient.sharedClient().setThread(thread, isBookmarked: isBookmarked) { [weak self] (error: NSError?) in
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataManager.contents[indexPath.row]
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.NextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let cell = cell as! ThreadTableViewCell
        let thread = dataManager.contents[indexPath.row]
        cell.themeData = ThreadTableViewCell.ThemeData(theme: theme, thread: thread)
    }
}
