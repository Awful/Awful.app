//  ThreadsTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

private let Log = Logger.get(level: .debug)

final class ThreadsTableViewController: TableViewController, ComposeTextViewControllerDelegate, ThreadTagPickerViewControllerDelegate, ThreadPeekPopControllerDelegate, UIViewControllerRestoration {
    private var dataSource: ThreadListDataSource?
    private var filterThreadTag: ThreadTag?
    let forum: Forum
    private var latestPage = 0
    private lazy var longPressRecognizer: UIGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
    }()
    private let managedObjectContext: NSManagedObjectContext
    private var peekPopController: ThreadPeekPopController?
    
    init(forum: Forum) {
        guard let managedObjectContext = forum.managedObjectContext else {
            fatalError("where's the context?")
        }
        self.managedObjectContext = managedObjectContext

        self.forum = forum
        
        super.init(style: .plain)
        
        title = forum.name
        
        navigationItem.rightBarButtonItem = composeBarButtonItem
        updateComposeBarButtonItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }

    private func makeDataSource() -> ThreadListDataSource {
        var filter: Set<ThreadTag> = []
        if let tag = filterThreadTag {
            filter.insert(tag)
        }
        let dataSource = try! ThreadListDataSource(
            forum: forum,
            sortedByUnread: AwfulSettings.shared().forumThreadsSortedByUnread,
            showsTagAndRating: AwfulSettings.shared().showThreadTags,
            threadTagFilter: filter,
            managedObjectContext: managedObjectContext,
            tableView: tableView)
        dataSource.delegate = self
        return dataSource
    }
    
    private func loadPage(_ page: Int) {
        ForumsClient.shared.listThreads(in: forum, tagged: filterThreadTag, page: page)
            .done { threads in
                self.latestPage = page

                self.scrollToLoadMoreBlock = { self.loadNextPage() }

                self.tableView.tableHeaderView = self.filterButton

                if self.filterThreadTag == nil {
                    RefreshMinder.sharedMinder.didRefreshForum(self.forum)
                } else {
                    RefreshMinder.sharedMinder.didRefreshFilteredForum(self.forum)
                }

                // Announcements appear in all thread lists.
                RefreshMinder.sharedMinder.didRefresh(.announcements)

                self.updateComposeBarButtonItem()
            }
            .catch { (error) in
                let alert = UIAlertController(networkError: error)
                self.present(alert, animated: true)
            }
            .finally {
                self.stopAnimatingPullToRefresh()
                self.stopAnimatingInfiniteScroll()
        }
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.addGestureRecognizer(longPressRecognizer)
        tableView.estimatedRowHeight = ThreadListCell.estimatedHeight
        tableView.hideExtraneousSeparators()
        tableView.restorationIdentifier = "Threads table view"
        
        dataSource = makeDataSource()
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ThreadsTableViewController.settingsDidChange(_:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        
        if traitCollection.forceTouchCapability == .available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        updateFilterButton()

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(showsTagAndRating: AwfulSettings.shared().showThreadTags, inTableWithWidth: tableView.bounds.width)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if tableView.numberOfSections > 0, tableView.numberOfRows(inSection: 0) > 0 {
            scrollToLoadMoreBlock = { [weak self] in self?.loadNextPage() }
            
            updateFilterButton()
            tableView.tableHeaderView = filterButton
        }
        
        prepareUserActivity()
        
        let isTimeToRefresh: Bool
        if filterThreadTag == nil {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshForum(forum)
        } else {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshFilteredForum(forum)
        }
        if isTimeToRefresh || tableView.numberOfSections == 0 || tableView.numberOfRows(inSection: 0) == 0 {
            refresh()
        }
    }
    
    // MARK: Actions

    @objc private func didLongPress(_ sender: UIGestureRecognizer) {
        guard case .began = sender.state else { return }
        
        guard let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView)) else {
            Log.d("ignoring long press, wasn't on a cell")
            return
        }

        guard let thread = dataSource?.thread(at: indexPath) else {
            Log.e("couldn't find thread?")
            return
        }

        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] (sourceRect, sourceView) in
            guard let self = self else { return }
            
            let targetView: UIView = self.dataSource
                .flatMap { $0.indexPath(of: thread) }
                .flatMap { self.tableView.cellForRow(at: $0) }
                ?? self.tableView
            
            sourceRect.pointee = targetView.bounds
            sourceView.pointee = targetView
        }
        present(actionViewController, animated: true)
    }
    
    private func loadNextPage() {
        loadPage(latestPage + 1)
    }
    
    private func refresh() {
        startAnimatingPullToRefresh()
        
        loadPage(1)
    }
    
    // MARK: Notifications
    
    @objc private func settingsDidChange(_ notification: Notification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }

        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() as String as String where isViewLoaded:
            dataSource = makeDataSource()
            tableView.reloadData()
            
        case AwfulSettingsKeys.forumThreadsSortedByUnread.takeUnretainedValue() as String as String:
            dataSource = makeDataSource()
            tableView.reloadData()
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() as String as String where visible:
            prepareUserActivity()
            
        default:
            break
        }
    }
    
    // MARK: Composition
    
    private lazy var composeBarButtonItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(ThreadsTableViewController.didTapCompose))
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
        composeBarButtonItem.isEnabled = forum.canPost && forum.lastRefresh != nil
    }
    
    @objc func didTapCompose() {
        present(threadComposeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: ComposeTextViewControllerDelegate
    
    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true) {
            if let thread = self.threadComposeViewController.thread , success {
                let postsPage = PostsPageViewController(thread: thread)
                postsPage.restorationIdentifier = "Posts"
                postsPage.loadPage(.first, updatingCache: true, updatingLastReadPost: true)
                self.showDetailViewController(postsPage, sender: self)
            }
            
            if !shouldKeepDraft {
                self.threadComposeViewController = nil
            }
        }
    }
    
    // MARK: Filtering by tag
    
    private lazy var filterButton: UIButton = { [unowned self] in
        let button = UIButton(type: .system)
        button.bounds.size.height = button.intrinsicContentSize.height + 8
        button.addTarget(self, action: #selector(ThreadsTableViewController.didTapFilterButton(_:)), for: .touchUpInside)
        return button
        }()
    
    private lazy var threadTagPicker: ThreadTagPickerViewController = { [unowned self] in
        let imageNames = self.forum.threadTags.array
            .filter { ($0 as! ThreadTag).imageName != nil }
            .map { ($0 as! ThreadTag).imageName! }
        let picker = ThreadTagPickerViewController(imageNames: [ThreadTagLoader.noFilterImageName] + imageNames, secondaryImageNames: nil)
        picker.delegate = self
        picker.title = "Filter Threads"
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        return picker
        }()
    
    @objc private func didTapFilterButton(_ sender: UIButton) {
        let imageName = filterThreadTag?.imageName ?? ThreadTagLoader.noFilterImageName
        threadTagPicker.selectImageName(imageName)
        threadTagPicker.present(fromView: sender)
    }
    
    private func updateFilterButton() {
        let title = filterThreadTag == nil ? "Filter By Tag" : "Change Filter"
        filterButton.setTitle(title, for: .normal)
        
        filterButton.tintColor = theme["tintColor"]
    }
    
    // MARK: ThreadTagPickerViewControllerDelegate
    
    func threadTagPicker(_ picker: ThreadTagPickerViewController, didSelectImageName imageName: String) {
        if imageName == ThreadTagLoader.noFilterImageName {
            filterThreadTag = nil
        } else {
            filterThreadTag = forum.threadTags.array.first { ($0 as! ThreadTag).imageName == imageName } as! ThreadTag?
        }
        
        RefreshMinder.sharedMinder.forgetForum(forum)
        updateFilterButton()

        dataSource = makeDataSource()
        tableView.reloadData()
        
        picker.dismiss()
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard AwfulSettings.shared().handoffEnabled else {
            userActivity = nil
            return
        }
        
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.listingThreads)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .forum(id: forum.forumID)
        activity.title = forum.name

        Log.d("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
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
    
    // MARK: UIViewControllerRestoration
    
    class func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        var forumKey = coder.decodeObject(forKey: RestorationKeys.forumKey) as! ForumKey?
        if forumKey == nil {
            guard let forumID = coder.decodeObject(forKey: ObsoleteRestorationKeys.forumID) as? String else { return nil }
            forumKey = ForumKey(forumID: forumID)
        }
        let managedObjectContext = AppDelegate.instance.managedObjectContext
        let forum = Forum.objectForKey(objectKey: forumKey!, inManagedObjectContext: managedObjectContext) as! Forum
        let viewController = self.init(forum: forum)
        viewController.restorationIdentifier = identifierComponents.last 
        viewController.restorationClass = self
        return viewController
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(forum.objectKey, forKey: RestorationKeys.forumKey)
        coder.encode(threadComposeViewController, forKey: RestorationKeys.newThreadViewController)
        coder.encode(filterThreadTag?.objectKey, forKey: RestorationKeys.filterThreadTagKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        if let compose = coder.decodeObject(forKey: RestorationKeys.newThreadViewController) as? ThreadComposeViewController {
            compose.delegate = self
            threadComposeViewController = compose
        }
        
        var tagKey = coder.decodeObject(forKey: RestorationKeys.filterThreadTagKey) as! ThreadTagKey?
        if tagKey == nil {
            if let tagID = coder.decodeObject(forKey: ObsoleteRestorationKeys.filterThreadTagID) as? String {
                tagKey = ThreadTagKey(imageName: nil, threadTagID: tagID)
            }
        }
        if let tagKey = tagKey {
            filterThreadTag = ThreadTag.objectForKey(objectKey: tagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
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

extension ThreadsTableViewController: ThreadListDataSourceDelegate {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme {
        return theme
    }
}

// MARK: UITableViewDelegate
extension ThreadsTableViewController {
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
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
