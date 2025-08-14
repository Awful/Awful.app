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
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BookmarksTableViewController")

final class BookmarksTableViewController: TableViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: ThreadListDataSource?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) private var handoffEnabled
    
    private var latestPage = 0
    private var loadMoreFooter: LoadMoreFooter?
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    @FoilDefaultStorage(Settings.bookmarksSortedUnread) private var sortUnreadToTop
    
    private var currentFilter: BookmarkFilter = .all
    private var filterButton: UIBarButtonItem!
    private var filterButtonView: UIButton!
    private var searchButton: UIBarButtonItem!
    private var searchBar: UISearchBar!
    private var searchBarContainerView: UIView!
    

    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        return ScrollViewDelegateMultiplexer(scrollView: tableView)
    }()

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init(style: .plain)
        
        title = LocalizedString("bookmarks.title")
        
        tabBarItem.image = UIImage(named: "bookmarks")
        tabBarItem.selectedImage = UIImage(named: "bookmarks-filled")
        
        setupFilterButton()
        setupSearchButton()
        setupSearchBar()
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItems = [filterButton, searchButton]
        
        themeDidChange()
    }
    
    private func setupFilterButton() {
        // Create a custom button for better context menu control
        filterButtonView = UIButton(type: .system)
        filterButtonView.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        filterButtonView.accessibilityLabel = "Filter bookmarks"
        
        // Set up context menu with explicit trait collection
        if #available(iOS 14.0, *) {
            setupFilterButtonMenu()
        } else {
            filterButtonView.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        }
        
        // Wrap in bar button item
        filterButton = UIBarButtonItem(customView: filterButtonView)
        
        // Update filter menu when theme changes
        updateFilterMenuIfNeeded()
    }
    
    @available(iOS 14.0, *)
    private func setupFilterButtonMenu() {
        let themeMode = theme[string: "mode"]
        let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
        
        // Force the button to use the correct interface style
        filterButtonView.overrideUserInterfaceStyle = userInterfaceStyle
        
        filterButtonView.menu = createFilterMenu()
        filterButtonView.showsMenuAsPrimaryAction = true
    }
    
    private func setupSearchButton() {
        searchButton = UIBarButtonItem(
            image: UIImage(named: "quick-look"),
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        searchButton.accessibilityLabel = "Search bookmarks"
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "Search by title or author..."
        searchBar.showsCancelButton = true
        searchBar.searchBarStyle = .minimal
        searchBar.isHidden = true // Start hidden
        
        searchBarContainerView = UIView()
        searchBarContainerView.addSubview(searchBar)
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: searchBarContainerView.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainerView.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainerView.trailingAnchor, constant: -16),
            searchBar.bottomAnchor.constraint(equalTo: searchBarContainerView.bottomAnchor, constant: -8)
        ])
    }
    
    @available(iOS 14.0, *)
    private func createFilterMenu() -> UIMenu {
        var actions: [UIMenuElement] = []
        
        // Basic filters
        let basicActions = [BookmarkFilter.all, .unreadOnly, .readOnly].map { filter in
            let isSelected = {
                switch (currentFilter, filter) {
                case (.all, .all), (.unreadOnly, .unreadOnly), (.readOnly, .readOnly):
                    return true
                default:
                    return false
                }
            }()
            
            return UIAction(
                title: filter.title,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.applyFilter(filter)
            }
        }
        
        actions.append(UIMenu(title: "", options: .displayInline, children: basicActions))
        
        // Star category filters
        let starActions = StarCategory.allCases.compactMap { category -> UIAction? in
            guard category != .none else { return nil }
            let filter = BookmarkFilter.starCategory(category)
            
            let isSelected = {
                if case .starCategory(let currentStar) = currentFilter {
                    return currentStar == category
                }
                return false
            }()
            
            return UIAction(
                title: filter.title,
                state: isSelected ? .on : .off
            ) { [weak self] _ in
                self?.applyFilter(filter)
            }
        }
        
        if !starActions.isEmpty {
            actions.append(UIMenu(title: "Star Categories", options: .displayInline, children: starActions))
        }
        
        return UIMenu(title: "Filter Bookmarks", children: actions)
    }
    
    @available(iOS 14.0, *)
    private func updateFilterMenu() {
        setupFilterButtonMenu()
    }
    
    private func updateFilterMenuIfNeeded() {
        if #available(iOS 14.0, *) {
            updateFilterMenu()
        }
    }
    
    @objc private func filterButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        let alert = UIAlertController(title: "Filter Bookmarks", message: nil, preferredStyle: .actionSheet)
        
        for filter in BookmarkFilter.quickFilters {
            let action = UIAlertAction(title: filter.title, style: .default) { [weak self] _ in
                self?.applyFilter(filter)
            }
            
            let isSelected: Bool
            switch (currentFilter, filter) {
            case (.all, .all), (.unreadOnly, .unreadOnly), (.readOnly, .readOnly):
                isSelected = true
            case (.starCategory(let currentStar), .starCategory(let filterStar)):
                isSelected = currentStar == filterStar
            default:
                isSelected = false
            }
            
            if isSelected {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = filterButton
        }
        
        present(alert, animated: true)
    }
    
    @objc private func searchButtonTapped() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        toggleSearchBar()
    }
    
    private func toggleSearchBar() {
        let isSearchVisible = searchBarContainerView.frame.height > 0
        
        if !isSearchVisible {
            // Show search bar with smooth animation
            searchBar.isHidden = false
            searchBar.alpha = 0
            
            // Start with height 0, then animate to full height
            searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
            tableView.tableHeaderView = searchBarContainerView
            
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseInOut],
                animations: {
                    // Animate height and alpha together
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 56)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 1.0
                },
                completion: { _ in
                    self.searchBar.becomeFirstResponder()
                }
            )
        } else {
            // Hide search bar with smooth animation
            searchBar.resignFirstResponder()
            searchBar.text = ""
            applyFilter(.all)
            
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.1,
                options: [.curveEaseInOut],
                animations: {
                    // Animate both height and alpha together
                    self.searchBarContainerView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0)
                    self.tableView.tableHeaderView = self.searchBarContainerView
                    self.searchBar.alpha = 0.0
                },
                completion: { _ in
                    self.searchBar.isHidden = true
                }
            )
        }
    }
    
    private func applyFilter(_ filter: BookmarkFilter) {
        currentFilter = filter
        dataSource = makeDataSource()
        tableView.reloadData()
        
        // Update filter menu for iOS 14+
        if #available(iOS 14.0, *) {
            updateFilterMenu()
        }
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
            filter: currentFilter,
            managedObjectContext: managedObjectContext,
            tableView: tableView
        )
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
        
        // Set up search bar as table header view initially hidden
        searchBarContainerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0)
        searchBarContainerView.clipsToBounds = true
        tableView.tableHeaderView = searchBarContainerView
        

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
        
        // Update navigation bar button colors to follow theme
        editButtonItem.tintColor = theme["navigationBarTextColor"]
        filterButton?.tintColor = theme["navigationBarTextColor"]
        filterButtonView?.tintColor = theme["navigationBarTextColor"]
        searchButton?.tintColor = theme["navigationBarTextColor"]
        
        // Update search bar theme
        if let searchBar = searchBar {
            searchBarContainerView.backgroundColor = theme["listBackgroundColor"]
            searchBar.barTintColor = theme["listBackgroundColor"]
            searchBar.backgroundColor = theme["listBackgroundColor"]
            searchBar.searchTextField.backgroundColor = theme["navigationBarBackgroundColor"]
            searchBar.searchTextField.textColor = theme["listTextColor"]
            searchBar.tintColor = theme["tintColor"]
        }
        
        // Update filter menu to match theme
        updateFilterMenuIfNeeded()

        // Set interface style for context menus to follow theme
        let themeMode = theme[string: "mode"]
        let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
        
        overrideUserInterfaceStyle = userInterfaceStyle
        tableView.overrideUserInterfaceStyle = userInterfaceStyle
        view.overrideUserInterfaceStyle = userInterfaceStyle
        
        // Update interface style for context menus
        if #available(iOS 14.0, *) {
            let themeMode = theme[string: "mode"]
            let userInterfaceStyle: UIUserInterfaceStyle = themeMode == "light" ? .light : .dark
            filterButtonView?.overrideUserInterfaceStyle = userInterfaceStyle
        }
        

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure context menu has correct appearance
        updateFilterMenuIfNeeded()
        
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

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        if tableView.isEditing {
            let delete = UIContextualAction(style: .destructive, title: LocalizedString("table-view.action.delete"), handler: { action, view, completion in
                guard let thread = self.dataSource?.thread(at: indexPath) else { return }
                self.setThread(thread, isBookmarked: false)
                completion(true)
            })
            let config = UISwipeActionsConfiguration(actions: [delete])
            config.performsFirstActionWithFullSwipe = false
            return config
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let thread = dataSource!.thread(at: indexPath)
        return UIContextMenuConfiguration.makeFromThreadList(for: thread, presenter: self, theme: theme)
    }


        
}

extension BookmarksTableViewController: ThreadListDataSourceDeletionDelegate {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource) {
        setThread(thread, isBookmarked: false)
    }
}

extension BookmarksTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            applyFilter(.all)
        } else {
            applyFilter(.textSearch(trimmedText))
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        toggleSearchBar()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
