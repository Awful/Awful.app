//  BookmarksTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class BookmarksTableViewController: TableViewController, ThreadPeekPopControllerDelegate {
    fileprivate var latestPage = 0
    fileprivate let managedObjectContext: NSManagedObjectContext
    fileprivate var peekPopController: ThreadPeekPopController?
    
    fileprivate typealias DataManager = FetchedDataManager<AwfulThread>
    
    fileprivate var dataManager: DataManager {
        didSet {
            tableViewAdapter = nil
            
            if isViewLoaded {
                createTableViewAdapter()
                
                tableView.reloadData()
            }
        }
    }
    
    fileprivate var tableViewAdapter: ThreadDataManagerTableViewAdapter!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        let fetchRequest = AwfulThread.bookmarksFetchRequest(AwfulSettings.shared().bookmarksSortedByUnread)
        dataManager = DataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
        
        super.init(style: .plain)
        
        title = "Bookmarks"
        
        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        ForumsClient.shared.listBookmarkedThreads(page: page)
            .then { (threads) -> Void in
                self.latestPage = page
                RefreshMinder.sharedMinder.didRefresh(.bookmarks)

                if threads.count >= 40 {
                    self.scrollToLoadMoreBlock = { self.loadMore() }
                }
                else {
                    self.scrollToLoadMoreBlock = nil
                }
            }
            .catch { (error) in
                guard self.visible else { return }
                let alert = UIAlertController(networkError: error as NSError, handler: nil)
                self.present(alert, animated: true, completion: nil)
            }
            .always {
                self.stopAnimatingPullToRefresh()
                self.stopAnimatingInfiniteScroll()
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: ThreadTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ThreadTableViewCell.identifier)
        
        tableView.estimatedRowHeight = ThreadTableViewCell.estimatedRowHeight
        tableView.restorationIdentifier = "Bookmarks table"
        tableView.separatorStyle = .none
        
        createTableViewAdapter()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(BookmarksTableViewController.settingsDidChange(notification:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        
        if traitCollection.forceTouchCapability == .available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        prepareUserActivity()
        
        if !dataManager.contents.isEmpty {
            scrollToLoadMoreBlock = { [weak self] in self?.loadMore() }
        }
        
        becomeFirstResponder()
        
        if ForumsClient.shared.isReachable &&
            (dataManager.contents.isEmpty || RefreshMinder.sharedMinder.shouldRefresh(.bookmarks))
        {
            refresh()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        undoManager.removeAllActions()
        
        resignFirstResponder()
    }
    
    // MARK: Actions
    
    private func didLongPressCell(cell: ThreadTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let thread = dataManager.contents[indexPath.row]
        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] sourceRect, sourceView in
            if let
                row = self?.dataManager.contents.index(of: thread),
                let cell = self?.tableView.cellForRow(at: IndexPath(row: row, section: 0))
            {
                sourceRect.pointee = cell.bounds
                sourceView.pointee = cell
            }
        }
        present(actionViewController, animated: true, completion: nil)
    }
    
    private func loadMore() {
        loadPage(page: latestPage + 1)
    }
    
    private func refresh() {
        startAnimatingPullToRefresh()
        loadPage(page: 1)
    }
    
    // MARK: Notifications
    
    @objc private func settingsDidChange(notification: NSNotification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }
        
        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() as String as String where isViewLoaded:
            createTableViewAdapter()
            tableView.reloadData()
            
        case AwfulSettingsKeys.bookmarksSortedByUnread.takeUnretainedValue() as String as String:
            let fetchRequest = AwfulThread.bookmarksFetchRequest(AwfulSettings.shared().bookmarksSortedByUnread)
            dataManager = DataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() as String as String where visible:
            prepareUserActivity()
            
        default:
            break
        }
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard AwfulSettings.shared().handoffEnabled else {
            userActivity = nil
            return
        }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityTypeListingThreads)
        activity.needsSave = true
        userActivity = activity
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.title = "Bookmarked Threads"
        activity.addUserInfoEntries(from: [Handoff.InfoBookmarksKey: true])
        activity.webpageURL = URL(string: "/bookmarkthreads.php", relativeTo: ForumsClient.shared.baseURL)
    }
    
    // MARK: ThreadPeekPopControllerDelegate
    
    func threadForLocation(location: CGPoint) -> AwfulThread? {
        guard let row = tableView.indexPathForRow(at: location)?.row else {
            return nil
        }
        
        return dataManager.contents[row]
    }
    
    func viewForThread(thread: AwfulThread) -> UIView? {
        guard let row = dataManager.contents.index(of: thread) else {
            return nil
        }
        
        return tableView.cellForRow(at: IndexPath(row: row, section: 0))
    }
    
    // MARK: Undo
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var undoManager: UndoManager {
        return _undoManager
    }
    
    fileprivate let _undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
        }()
    
    @objc fileprivate func setThread(_ thread: AwfulThread, isBookmarked: Bool) {
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = false
        _ = ForumsClient.shared.setThread(thread, isBookmarked: isBookmarked)
            .catch { [weak self] (error) -> Void in
                let alert = UIAlertController(networkError: error as NSError, handler: nil)
                self?.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = dataManager.contents[indexPath.row]
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.nextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        let cell = cell as! ThreadTableViewCell
        let thread = dataManager.contents[indexPath.row]
        cell.themeData = ThreadTableViewCell.ThemeData(theme: theme, thread: thread)
    }
}
