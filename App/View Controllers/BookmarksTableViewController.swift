//  BookmarksTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get(level: .debug)

final class BookmarksTableViewController: TableViewController, ThreadPeekPopControllerDelegate {
    private var dataSource: ThreadListDataSource?
    private var latestPage = 0
    private lazy var longPressRecognizer: UIGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
    }()
    private let managedObjectContext: NSManagedObjectContext
    private var peekPopController: ThreadPeekPopController?

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init(style: .plain)
        
        title = "Bookmarks"
        
        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeDataSource() -> ThreadListDataSource {
        let dataSource = try! ThreadListDataSource(bookmarksSortedByUnread: AwfulSettings.shared().bookmarksSortedByUnread, showsTagAndRating: AwfulSettings.shared().showThreadTags, managedObjectContext: managedObjectContext, tableView: tableView)
        dataSource.deletionDelegate = self
        return dataSource
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
                let alert = UIAlertController(networkError: error)
                self.present(alert, animated: true)
            }
            .always {
                self.stopAnimatingPullToRefresh()
                self.stopAnimatingInfiniteScroll()
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.addGestureRecognizer(longPressRecognizer)
        tableView.hideExtraneousSeparators()
        tableView.restorationIdentifier = "Bookmarks table"

        dataSource = makeDataSource()
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(BookmarksTableViewController.settingsDidChange(notification:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        
        if traitCollection.forceTouchCapability == .available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(showsTagAndRating: AwfulSettings.shared().showThreadTags, inTableWithWidth: tableView.bounds.width)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        prepareUserActivity()
        
        if tableView.numberOfSections > 0, tableView.numberOfRows(inSection: 0) > 0 {
            scrollToLoadMoreBlock = { [weak self] in self?.loadMore() }
        }
        
        becomeFirstResponder()
        
        if tableView.numberOfSections == 0
            || tableView.numberOfRows(inSection: 0) == 0
            || RefreshMinder.sharedMinder.shouldRefresh(.bookmarks)
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
    
    @objc private func didLongPress(_ sender: UIGestureRecognizer) {
        guard let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView)) else {
            Log.d("ignoring long press, wasn't on a cell")
            return
        }

        guard let thread = dataSource?.thread(at: indexPath) else {
            Log.e("couldn't find thread?")
            return
        }

        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] sourceRect, sourceView in
            guard let sself = self else { return }

            if
                let indexPath = sself.dataSource?.indexPath(of: thread),
                let cell = sself.tableView.cellForRow(at: indexPath)
            {
                sourceRect.pointee = cell.bounds
                sourceView.pointee = cell
            }
        }
        present(actionViewController, animated: true)
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
            dataSource = makeDataSource()
            tableView.reloadData()
            
        case AwfulSettingsKeys.bookmarksSortedByUnread.takeUnretainedValue() as String as String:
            dataSource = makeDataSource()
            tableView.reloadData()
            
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
        return tableView
            .indexPathForRow(at: location)
            .flatMap { dataSource?.thread(at: $0) }
    }
    
    func viewForThread(thread: AwfulThread) -> UIView? {
        return dataSource?
            .indexPath(of: thread)
            .flatMap { tableView.cellForRow(at: $0) }
    }
    
    // MARK: Undo
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var undoManager: UndoManager {
        return _undoManager
    }
    
    private let _undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
        }()
    
    @objc private func setThread(_ thread: AwfulThread, isBookmarked: Bool) {
        (undoManager.prepare(withInvocationTarget: self) as AnyObject).setThread(thread, isBookmarked: !isBookmarked)
        undoManager.setActionName("Delete")
        
        thread.bookmarked = false

        ForumsClient.shared.setThread(thread, isBookmarked: isBookmarked)
            .catch { [weak self] (error) -> Void in
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
        }
    }
}


// MARK: UITableViewDelegate
extension BookmarksTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource!.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = dataSource!.thread(at: indexPath)
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
    }

    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: LocalizedString("table-view.action.delete"), handler: { action, view, completion in
            guard let thread = self.dataSource?.thread(at: indexPath) else { return }
            self.setThread(thread, isBookmarked: false)
            completion(true)
        })
        let config = UISwipeActionsConfiguration(actions: [delete])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

extension BookmarksTableViewController: ThreadListDataSourceDeletionDelegate {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource) {
        setThread(thread, isBookmarked: false)
    }
}
