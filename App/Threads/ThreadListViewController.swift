//  ThreadListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

class ThreadListViewController: AwfulTableViewController {
    var dataSource: DataSource! {
        didSet {
            dataSource?.delegate = self
            if isViewLoaded() {
                tableView.dataSource = dataSource
                tableView.reloadData()
            }
        }
    }
    
    var sortByUnreadSettingsKey: String {
        fatalError("subclass implementation please")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        makeNewDataSource()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let settingsObserver: AnyObject = settingsObserver {
            NSNotificationCenter.defaultCenter().removeObserver(settingsObserver)
        }
    }
    
    func makeNewDataSource() {
        fatalError("subclass implementation please")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 75
        tableView.separatorStyle = .None
        tableView.registerNib(UINib(nibName: ThreadTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ThreadTableViewCell.identifier)
        tableView.dataSource = dataSource
        
        settingsObserver = NSNotificationCenter.defaultCenter().addObserverForName(AwfulSettingsDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            if let key = note.userInfo?[AwfulSettingsDidChangeSettingKey] as? String {
                if key == AwfulSettingsKeys.showThreadTags.takeUnretainedValue() {
                    if self.isViewLoaded() {
                        self.tableView.reloadData()
                    }
                } else if key == self.sortByUnreadSettingsKey {
                    self.makeNewDataSource()
                }
            }
        }
    }
    
    private var settingsObserver: AnyObject?
}

extension ThreadListViewController {
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let
            cell = cell as? ThreadTableViewCell,
            thread = dataSource.itemAtIndexPath(indexPath) as? Thread
        else { return }
        
        cell.themeData = ThreadTableViewCell.ThemeData(theme: theme, thread: thread)
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataSource.itemAtIndexPath(indexPath) as! Thread
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.NextUnread.rawValue : 1
        postsViewController.loadPage(targetPage, updatingCache: true)
        showDetailViewController(postsViewController, sender: self)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

class ThreadDataSource: FetchedDataSource {
    private var threadTagObservers = [String: AwfulNewThreadTagObserver]()
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // TODO: Bring back thread tag update observation. (should probably do it as a reload and track it by thread)
        let cell = tableView.dequeueReusableCellWithIdentifier(ThreadTableViewCell.identifier, forIndexPath: indexPath) as! ThreadTableViewCell
        let thread = itemAtIndexPath(indexPath) as! Thread
        
        cell.longPress.removeTarget(self, action: nil)
        cell.longPress.addTarget(self, action: "didLongPress:")
        
        cell.viewModel = ThreadTableViewCell.ViewModel(thread: thread, showsTag: AwfulSettings.sharedSettings().showThreadTags)
        
        return cell
    }
    
    @objc private func didLongPress(sender: UILongPressGestureRecognizer) {
        let cell = sender.view as! UITableViewCell
        // TODO: nearestSuperviewOfDeclaredType sucks, do something else
        let tableView: UITableView = cell.nearestSuperviewOfDeclaredType()
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        let thread = itemAtIndexPath(indexPath) as! Thread
        
        showActionsForThread(thread, forTableView: tableView)
    }
    
    private func showActionsForThread(thread: Thread, forTableView tableView: UITableView) {
        let viewController = tableView.awful_viewController
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
        
        let actionViewController = InAppActionViewController()
        actionViewController.items = items
        actionViewController.popoverPositioningBlock = { sourceRect, sourceView in
            if let indexPath = self.indexPathsForItem(thread).first {
                if let cell = tableView.cellForRowAtIndexPath(indexPath) {
                    sourceRect.memory = cell.bounds
                    sourceView.memory = cell
                }
            }
        }
        viewController.presentViewController(actionViewController, animated: true, completion: nil)
    }
}
