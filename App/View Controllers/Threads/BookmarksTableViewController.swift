//  BookmarksTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import os
import ScrollViewDelegateMultiplexer
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookmarksTableViewController")

final class BookmarksTableViewController: TableViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    var coordinator: (any MainCoordinator)?
    private var dataSource: ThreadListDataSource?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    private var latestPage = 0
    private var loadMoreFooter: LoadMoreFooter?
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.bookmarksSortedUnread) private var sortUnreadToTop

    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        return ScrollViewDelegateMultiplexer(scrollView: tableView)
    }()

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init(style: .plain)
        
        title = LocalizedString("bookmarks.title")
        
        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")
        navigationItem.rightBarButtonItem = editButtonItem
        
        themeDidChange()
    }
    
    deinit {
        if isViewLoaded {
            multiplexer.removeDelegate(self)
        }
    }

    private func makeDataSource() -> ThreadListDataSource {
        let dataSource = try! ThreadListDataSource(
            bookmarksSortedByUnread: sortUnreadToTop,
            showsTagAndRating: showThreadTags,
            managedObjectContext: managedObjectContext,
            tableView: tableView
        )
        dataSource.delegate = self
        dataSource.deletionDelegate = self
        return dataSource
    }
    
    private func loadPage(page: Int) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        Task {
            do {
                let threads = try await ForumsClient.shared.listBookmarkedThreads(page: page)
                latestPage = page
                RefreshMinder.sharedMinder.didRefresh(.bookmarks)

                if threads.count >= 40 {
                    enableLoadMore()
                } else {
                    disableLoadMore()
                }
            } catch {
                if visible {
                    let alert = UIAlertController(networkError: error)
                    present(alert, animated: true)
                }
            }
            stopAnimatingPullToRefresh()
            loadMoreFooter?.didFinish()
        }
    }
    
    private func enableLoadMore() {
        guard loadMoreFooter == nil else { return }
        
        loadMoreFooter = LoadMoreFooter(tableView: tableView, multiplexer: multiplexer, loadMore: { [weak self] loadMoreFooter in
            guard let self = self else { return }
            self.loadPage(page: self.latestPage + 1)
        })
    }
    
    private func disableLoadMore() {
        loadMoreFooter?.removeFromTableView()
        loadMoreFooter = nil
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multiplexer.addDelegate(self)

        tableView.hideExtraneousSeparators()
        tableView.restorationIdentifier = "Bookmarks table"

        dataSource = makeDataSource()
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }

        $handoffEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.prepareUserActivity() }
            .store(in: &cancellables)

        Publishers.Merge($showThreadTags.dropFirst(), $sortUnreadToTop.dropFirst())
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                dataSource = makeDataSource()
                tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        // Takes care of toggling the button's title.
        super.setEditing(editing, animated: true)

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Toggle table view editing.
        tableView.setEditing(editing, animated: true)
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        loadMoreFooter?.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.delegate = self
        
        prepareUserActivity()
        
        if tableView.numberOfSections > 0, tableView.numberOfRows(inSection: 0) > 0 {
            enableLoadMore()
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

    private func refresh() {
        startAnimatingPullToRefresh()
        loadPage(page: 1)
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard handoffEnabled else {
            userActivity = nil
            return
        }
        
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .bookmarks
        activity.title = LocalizedString("handoff.bookmarks-title")

        logger.debug("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
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

        Task { [weak self] in
            do {
                try await ForumsClient.shared.setThread(thread, isBookmarked: isBookmarked)
            } catch {
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
            }
        }
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: UITableViewDelegate
extension BookmarksTableViewController: UINavigationControllerDelegate {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource!.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let thread = dataSource?.thread(at: indexPath) else { return }
        
        // Check if we're in a split view (iPad) and use coordinator navigation
        if let coordinator = coordinator, UIDevice.current.userInterfaceIdiom == .pad {
            coordinator.navigateToThread(thread)
        } else {
            // iPhone: use traditional navigation
            // Use Task to avoid "Publishing changes from within view updates" warning
            Task { @MainActor in
                coordinator?.isDetailViewShowing = true
            }
            let postsViewController = PostsPageViewController(thread: thread)
            postsViewController.hidesBottomBarWhenPushed = true
            let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
            postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
            postsViewController.restorationIdentifier = "Posts"
            navigationController?.pushViewController(postsViewController, animated: true)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let thread = dataSource?.thread(at: indexPath) else { return nil }
        
        let unbookmarkAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.setThread(thread, isBookmarked: false)
            completion(true)
        }
        
        let lastPostAction = UIContextualAction(style: .normal, title: "Last Post") { [weak self] _, _, completion in
            // Check if we're in a split view (iPad) and use coordinator navigation
            if let coordinator = self?.coordinator, UIDevice.current.userInterfaceIdiom == .pad {
                coordinator.navigateToThread(thread)
                // TODO: We need to handle the specific page (.last) in the coordinator or PostsViewRepresentable
            } else {
                let postsViewController = PostsPageViewController(thread: thread)
                postsViewController.loadPage(.last, updatingCache: true, updatingLastReadPost: true)
                self?.showDetailViewController(postsViewController, sender: self)
            }
            completion(true)
        }
        lastPostAction.backgroundColor = self.theme["themeColor"]
        
        let firstPostAction = UIContextualAction(style: .normal, title: "Unread") { [weak self] _, _, completion in
            // Check if we're in a split view (iPad) and use coordinator navigation
            if let coordinator = self?.coordinator, UIDevice.current.userInterfaceIdiom == .pad {
                coordinator.navigateToThread(thread)
                // TODO: We need to handle the specific page (.nextUnread) in the coordinator or PostsViewRepresentable
            } else {
                let postsViewController = PostsPageViewController(thread: thread)
                postsViewController.loadPage(.nextUnread, updatingCache: false, updatingLastReadPost: true)
                self?.showDetailViewController(postsViewController, sender: self)
            }
            completion(true)
        }
        firstPostAction.backgroundColor = UIColor.lightGray
        
        return .init(actions: [unbookmarkAction, lastPostAction, firstPostAction])
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
        
    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let configuration = UIContextMenuConfiguration.makeFromThreadList(
            for: dataSource!.thread(at: indexPath),
               presenter: self
        )
        if #available(iOS 16.0, *) {
            configuration.preferredMenuElementOrder = .fixed
        }
        return configuration
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // Use Task to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            if viewController == self {
                coordinator?.isDetailViewShowing = false
            } else if navigationController.viewControllers.count > 1 {
                coordinator?.isDetailViewShowing = true
            } else {
                coordinator?.isDetailViewShowing = false
            }
        }
    }
}

extension BookmarksTableViewController: ThreadListDataSourceDelegate {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme {
        return theme
    }
}

// MARK: ThreadListDataSourceDeletionDelegate

extension BookmarksTableViewController: ThreadListDataSourceDeletionDelegate {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource) {
        setThread(thread, isBookmarked: false)
    }
}