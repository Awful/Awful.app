//  ThreadsTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

private let Log = Logger.get()

final class ThreadsTableViewController: TableViewController, ComposeTextViewControllerDelegate, ThreadTagPickerViewControllerDelegate, UIViewControllerRestoration {
    
    private var dataSource: ThreadListDataSource?
    private var filterThreadTag: ThreadTag?
    let forum: Forum
    private var latestPage = 0
    private var loadMoreFooter: LoadMoreFooter?
    private let managedObjectContext: NSManagedObjectContext
    private var observers: [NSKeyValueObservation] = []

    #if !targetEnvironment(macCatalyst)
    private var peekPopController: ThreadPeekPopController?
    #endif
    
    private lazy var longPressRecognizer: UIGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
    }()
    
    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        return ScrollViewDelegateMultiplexer(scrollView: tableView)
    }()
    
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
    
    deinit {
        if isViewLoaded {
            multiplexer.removeDelegate(self)
        }
    }
    
    override var theme: Theme {
        return Theme.currentTheme(for: forum)
    }

    private func makeDataSource() -> ThreadListDataSource {
        var filter: Set<ThreadTag> = []
        if let tag = filterThreadTag {
            filter.insert(tag)
        }
        let dataSource = try! ThreadListDataSource(
            forum: forum,
            sortedByUnread: UserDefaults.standard.sortUnreadForumThreadsFirst,
            showsTagAndRating: UserDefaults.standard.showThreadTagsInThreadList,
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

                self.enableLoadMore()

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
                self.loadMoreFooter?.didFinish()
        }
    }
    
    private func enableLoadMore() {
        guard loadMoreFooter == nil else { return }
        
        loadMoreFooter = LoadMoreFooter(tableView: tableView, multiplexer: multiplexer, loadMore: { [weak self] loadMoreFooter in
            self?.loadNextPage()
        })
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multiplexer.addDelegate(self)

        tableView.addGestureRecognizer(longPressRecognizer)
        tableView.estimatedRowHeight = ThreadListCell.estimatedHeight
        tableView.hideExtraneousSeparators()
        tableView.restorationIdentifier = "Threads table view"
        
        dataSource = makeDataSource()
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }

        #if !targetEnvironment(macCatalyst)
        if traitCollection.forceTouchCapability == .available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
        #endif
        
        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.isHandoffEnabled) { [weak self] defaults in
                guard let self = self else { return }
                if self.visible {
                    self.prepareUserActivity()
                }
            }
            $0.observe(\.sortUnreadForumThreadsFirst, \.showThreadTagsInThreadList) {
                [weak self] defaults in
                guard let self = self else { return }
                self.dataSource = self.makeDataSource()
                self.tableView.reloadData()
            }
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        loadMoreFooter?.themeDidChange()
        
        updateFilterButton()

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.separatorInset.left = ThreadListCell.separatorLeftInset(showsTagAndRating: UserDefaults.standard.showThreadTagsInThreadList, inTableWithWidth: tableView.bounds.width)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if tableView.numberOfSections > 0, tableView.numberOfRows(inSection: 0) > 0 {
            enableLoadMore()
            
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
    
    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.bounds.size.height = button.intrinsicContentSize.height + 8
        button.addTarget(self, action: #selector(didTapFilterButton), for: .primaryActionTriggered)
        return button
    }()
    
    private lazy var threadTagPicker: ThreadTagPickerViewController = {
        let imageNames = self.forum.threadTags.array
            .filter { ($0 as! ThreadTag).imageName != nil }
            .map { ($0 as! ThreadTag).imageName! }
        let picker = ThreadTagPickerViewController(firstTag: .noFilter, imageNames: imageNames, secondaryImageNames: [])
        picker.delegate = self
        picker.title = LocalizedString("thread-list.filter.picker-title")
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        return picker
    }()
    
    @objc private func didTapFilterButton(_ sender: UIButton) {
        threadTagPicker.selectImageName(filterThreadTag?.imageName)
        threadTagPicker.present(from: self, sourceView: sender)
    }
    
    private func updateFilterButton() {
        let title = LocalizedString(filterThreadTag == nil ? "thread-list.filter-button.no-filter" : "thread-list.filter-button.change-filter")
        filterButton.setTitle(title, for: .normal)
        
        filterButton.tintColor = theme["tintColor"]
    }
    
    // MARK: ThreadTagPickerViewControllerDelegate
    
    func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController) {
        if let imageName = imageName {
            filterThreadTag = forum.threadTags.array
                .compactMap { $0 as? ThreadTag }
                .first { $0.imageName == imageName }
        } else {
            filterThreadTag = nil
        }
        
        RefreshMinder.sharedMinder.forgetForum(forum)
        updateFilterButton()

        dataSource = makeDataSource()
        tableView.reloadData()
        
        picker.dismiss()
    }
    
    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
        // nop
    }
    
    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        // nop
    }
    
    // MARK: Handoff
    
    private func prepareUserActivity() {
        guard UserDefaults.standard.isHandoffEnabled else {
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
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ThreadsTableViewController: ThreadListDataSourceDelegate {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme {
        return theme
    }
}

// MARK: ThreadPeekPopControllerDelegate
#if !targetEnvironment(macCatalyst)
extension ThreadsTableViewController: ThreadPeekPopControllerDelegate {
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
}
#endif

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
