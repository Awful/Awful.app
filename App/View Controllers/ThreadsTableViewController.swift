//  ThreadsTableViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class ThreadsTableViewController: TableViewController, ComposeTextViewControllerDelegate, ThreadTagPickerViewControllerDelegate, ThreadPeekPopControllerDelegate, UIViewControllerRestoration {
    let forum: Forum
    fileprivate var latestPage = 0
    fileprivate var peekPopController: ThreadPeekPopController?
    
    fileprivate var filterThreadTag: ThreadTag?
    
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
    
    init(forum: Forum) {
        self.forum = forum
        let fetchRequest = AwfulThread.threadsFetchRequest(forum, sortedByUnread: AwfulSettings.shared().forumThreadsSortedByUnread, filterThreadTag: filterThreadTag)
        dataManager = DataManager(managedObjectContext: forum.managedObjectContext!, fetchRequest: fetchRequest)
        
        super.init(style: .plain)
        
        title = forum.name
        
        navigationItem.rightBarButtonItem = composeBarButtonItem
        updateComposeBarButtonItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }
    
    fileprivate func createTableViewAdapter() {
        tableViewAdapter = ThreadDataManagerTableViewAdapter(tableView: tableView, dataManager: dataManager, ignoreSticky: false, cellConfigurationHandler: { [weak self] cell, viewModel in
            cell.viewModel = viewModel
            cell.longPressAction = self?.didLongPressCell
        })
        
        dataManager.delegate = tableViewAdapter
        tableView.dataSource = tableViewAdapter
    }
    
    fileprivate func loadPage(_ page: Int) {
        ForumsClient.shared.listThreads(in: forum, tagged: filterThreadTag, page: page)
            .then { (threads) -> Void in
                self.latestPage = page

                self.scrollToLoadMoreBlock = { self.loadNextPage() }

                self.tableView.tableHeaderView = self.filterButton

                if self.filterThreadTag == nil {
                    RefreshMinder.sharedMinder.didRefreshForum(self.forum)
                } else {
                    RefreshMinder.sharedMinder.didRefreshFilteredForum(self.forum)
                }

                self.updateComposeBarButtonItem()
            }
            .catch { (error) in
                let alert = UIAlertController(networkError: error, handler: nil)
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
        tableView.restorationIdentifier = "Threads table view"
        tableView.separatorStyle = .none
        
        createTableViewAdapter()
        
        pullToRefreshBlock = { [weak self] in self?.refresh() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ThreadsTableViewController.settingsDidChange(_:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        
        if traitCollection.forceTouchCapability == .available {
            peekPopController = ThreadPeekPopController(previewingViewController: self)
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        updateFilterButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !dataManager.contents.isEmpty {
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
        if isTimeToRefresh || dataManager.contents.isEmpty {
            refresh()
        }
    }
    
    // MARK: Actions
    
    fileprivate func didLongPressCell(_ cell: ThreadTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        
        let thread = dataManager.contents[indexPath.row]
        let actionViewController = InAppActionViewController(thread: thread, presentingViewController: self)
        actionViewController.popoverPositioningBlock = { [weak self] (sourceRect, sourceView) in
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
    
    fileprivate func loadNextPage() {
        loadPage(latestPage + 1)
    }
    
    fileprivate func refresh() {
        startAnimatingPullToRefresh()
        
        loadPage(1)
    }
    
    // MARK: Notifications
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        guard let key = (notification as NSNotification).userInfo?[AwfulSettingsDidChangeSettingKey] as? String else {
            return
        }

        switch key {
        case AwfulSettingsKeys.showThreadTags.takeUnretainedValue() as String as String where isViewLoaded:
            createTableViewAdapter()
            tableView.reloadData()
            
        case AwfulSettingsKeys.forumThreadsSortedByUnread.takeUnretainedValue() as String as String:
            let fetchRequest = AwfulThread.threadsFetchRequest(forum, sortedByUnread: AwfulSettings.shared().forumThreadsSortedByUnread, filterThreadTag: filterThreadTag)
            dataManager = DataManager(managedObjectContext: forum.managedObjectContext!, fetchRequest: fetchRequest)
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue() as String as String where visible:
            prepareUserActivity()
            
        default:
            break
        }
    }
    
    // MARK: Composition
    
    fileprivate lazy var composeBarButtonItem: UIBarButtonItem = { [unowned self] in
        let item = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(ThreadsTableViewController.didTapCompose))
        item.accessibilityLabel = "New thread"
        return item
        }()
    
    fileprivate lazy var threadComposeViewController: ThreadComposeViewController! = { [unowned self] in
        let composeViewController = ThreadComposeViewController(forum: self.forum)
        composeViewController.restorationIdentifier = "New thread composition"
        composeViewController.delegate = self
        return composeViewController
        }()
    
    fileprivate func updateComposeBarButtonItem() {
        composeBarButtonItem.isEnabled = forum.canPost && forum.lastRefresh != nil
    }
    
    func didTapCompose() {
        present(threadComposeViewController.enclosingNavigationController, animated: true, completion: nil)
    }
    
    // MARK: ComposeTextViewControllerDelegate
    
    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true) {
            if let thread = self.threadComposeViewController.thread , success {
                let postsPage = PostsPageViewController(thread: thread)
                postsPage.restorationIdentifier = "Posts"
                postsPage.loadPage(1, updatingCache: true, updatingLastReadPost: true)
                self.showDetailViewController(postsPage, sender: self)
            }
            
            if !shouldKeepDraft {
                self.threadComposeViewController = nil
            }
        }
    }
    
    // MARK: Filtering by tag
    
    fileprivate lazy var filterButton: UIButton = { [unowned self] in
        let button = UIButton(type: .system)
        button.bounds.size.height = button.intrinsicContentSize.height + 8
        button.addTarget(self, action: #selector(ThreadsTableViewController.didTapFilterButton(_:)), for: .touchUpInside)
        return button
        }()
    
    fileprivate lazy var threadTagPicker: ThreadTagPickerViewController = { [unowned self] in
        let imageNames = self.forum.threadTags.array
            .filter { ($0 as! ThreadTag).imageName != nil }
            .map { ($0 as! ThreadTag).imageName! }
        let picker = ThreadTagPickerViewController(imageNames: [ThreadTagLoader.noFilterImageName] + imageNames, secondaryImageNames: nil)
        picker.delegate = self
        picker.title = "Filter Threads"
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        return picker
        }()
    
    @objc fileprivate func didTapFilterButton(_ sender: UIButton) {
        let imageName = filterThreadTag?.imageName ?? ThreadTagLoader.noFilterImageName
        threadTagPicker.selectImageName(imageName)
        threadTagPicker.present(fromView: sender)
    }
    
    fileprivate func updateFilterButton() {
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
        
        let fetchRequest = AwfulThread.threadsFetchRequest(forum, sortedByUnread: AwfulSettings.shared().forumThreadsSortedByUnread, filterThreadTag: filterThreadTag)
        dataManager = DataManager(managedObjectContext: forum.managedObjectContext!, fetchRequest: fetchRequest)
        
        picker.dismiss()
    }
    
    // MARK: Handoff
    
    fileprivate func prepareUserActivity() {
        guard AwfulSettings.shared().handoffEnabled else {
            userActivity = nil
            return
        }
        
        let activity = NSUserActivity(activityType: Handoff.ActivityTypeListingThreads)
        activity.needsSave = true
        userActivity = activity
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.title = forum.name
        activity.addUserInfoEntries(from: [Handoff.InfoForumIDKey: forum.forumID])
        activity.webpageURL = URL(string: "https://forums.somethingawful.com/forumdisplay.php?forumid=\(forum.forumID)")
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
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let thread = dataManager.contents[indexPath.row]
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.nextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        let cell = cell as! ThreadTableViewCell
        let thread = dataManager.contents[indexPath.row]
        cell.themeData = ThreadTableViewCell.ThemeData(theme: theme, thread: thread)
    }
    
    // MARK: UIViewControllerRestoration
    
    class func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        var forumKey = coder.decodeObject(forKey: RestorationKeys.forumKey) as! ForumKey!
        if forumKey == nil {
            guard let forumID = coder.decodeObject(forKey: ObsoleteRestorationKeys.forumID) as? String else { return nil }
            forumKey = ForumKey(forumID: forumID)
        }
        let managedObjectContext = AppDelegate.instance.managedObjectContext
        let forum = Forum.objectForKey(objectKey: forumKey!, inManagedObjectContext: managedObjectContext) as! Forum
        let viewController = self.init(forum: forum)
        viewController.restorationIdentifier = identifierComponents.last as! String?
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
    
    fileprivate struct RestorationKeys {
        static let forumKey = "ForumKey"
        static let newThreadViewController = "AwfulNewThreadViewController"
        static let filterThreadTagKey = "FilterThreadTagKey"
    }
    
    fileprivate struct ObsoleteRestorationKeys {
        static let forumID = "AwfulForumID"
        static let filterThreadTagID = "AwfulFilterThreadTagID"
    }
}
