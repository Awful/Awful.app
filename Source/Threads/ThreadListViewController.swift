//  ThreadListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Lists threads in ThreadCells.
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
    
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
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
        tableView.registerNib(UINib(nibName: "ThreadCell", bundle: nil), forCellReuseIdentifier: "Thread")
        tableView.dataSource = dataSource
        
        settingsObserver = NSNotificationCenter.defaultCenter().addObserverForName(AwfulSettingsDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            if let key = note.userInfo?[AwfulSettingsDidChangeSettingKey] as? String {
                if key == AwfulSettingsKeys.showThreadTags {
                    if self.isViewLoaded() {
                        self.tableView.reloadData()
                    }
                } else if key == AwfulSettingsKeys.threadsSortedByUnread {
                    self.makeNewDataSource()
                }
            }
        }
    }
    
    private var settingsObserver: AnyObject?
}

extension ThreadListViewController: UITableViewDelegate {
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = cell as? ThreadCell {
            let thread = dataSource.itemAtIndexPath(indexPath) as Thread

            cell.backgroundColor = theme["listBackgroundColor"] as UIColor?
            cell.titleLabel.textColor = theme["listTextColor"] as UIColor?
            cell.numberOfPagesLabel.textColor = theme["listSecondaryTextColor"] as UIColor?
            cell.pageIcon.borderColor = theme["listSecondaryTextColor"] as UIColor? ?? UIColor.grayColor()
            cell.killedByLabel.textColor = theme["listSecondaryTextColor"] as UIColor?
            cell.tintColor = theme["listSecondaryTextColor"] as UIColor?
            cell.fontNameForLabels = theme["listFontName"] as String?
            cell.separator.backgroundColor = theme["listSeparatorColor"] as UIColor?
            
            cell.selectedBackgroundView = UIView()
            cell.selectedBackgroundView.backgroundColor = theme["listSelectedBackgroundColor"] as UIColor?
            
            switch (thread.unreadPosts, thread.starCategory) {
            case (0, _): cell.unreadRepliesLabel.textColor = UIColor.grayColor()
            case (_, .Orange): cell.unreadRepliesLabel.textColor = theme["unreadBadgeOrangeColor"] as UIColor?
            case (_, .Red): cell.unreadRepliesLabel.textColor = theme["unreadBadgeRedColor"] as UIColor?
            case (_, .Yellow): cell.unreadRepliesLabel.textColor = theme["unreadBadgeYellowColor"] as UIColor?
            case (_, .None): cell.unreadRepliesLabel.textColor = theme["tintColor"] as UIColor?
            }
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataSource.itemAtIndexPath(indexPath) as Thread
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
        let cell = tableView.dequeueReusableCellWithIdentifier("Thread", forIndexPath: indexPath) as ThreadCell
        let thread = itemAtIndexPath(indexPath) as Thread
        cell.setLongPressTarget(self, action: "showThreadActions:")
        
        cell.showsTag = AwfulSettings.sharedSettings().showThreadTags
        if cell.showsTag {
            if let imageName = nonempty(thread.threadTag?.imageName) {
                if let image = AwfulThreadTagLoader.imageNamed(imageName) {
                    cell.tagImageView.image = image
                } else {
                    cell.tagImageView.image = AwfulThreadTagLoader.emptyThreadTagImage()
                    
                    let threadID = thread.threadID
                    threadTagObservers[threadID] = AwfulNewThreadTagObserver(imageName: imageName) { [unowned self] image in
                        if let indexPath = tableView.indexPathForCell(cell) {
                            let thread = self.itemAtIndexPath(indexPath) as Thread
                            if thread.threadID == threadID {
                                cell.tagImageView.image = image
                            }
                        }
                        self.threadTagObservers.removeValueForKey(threadID)
                    }
                }
            } else {
                cell.tagImageView.image = AwfulThreadTagLoader.emptyThreadTagImage()
            }
            
            if let secondaryImageName = nonempty(thread.secondaryThreadTag?.imageName) {
                cell.secondaryTagImageView.image = AwfulThreadTagLoader.imageNamed(secondaryImageName)
                cell.secondaryTagImageView.hidden = false
            } else {
                cell.secondaryTagImageView.hidden = true
            }
        
            cell.showsRating = AwfulForumTweaks(forumID: thread.forum?.forumID).showRatings
            if cell.showsRating {
                let rating = lroundf(thread.rating).clamp(0...5)
                if rating == 0 {
                    cell.showsRating = false
                } else {
                    cell.ratingImageView.image = UIImage(named: "rating\(rating)")
                }
            }
        }
        
        cell.titleLabel.text = thread.title
        
        let faded = thread.closed && !thread.sticky
        cell.tagAndRatingContainerView.alpha = faded ? 0.5 : 1
        cell.titleLabel.enabled = !faded
        
        cell.numberOfPagesLabel.text = "\(thread.numberOfPages)"
        
        if thread.beenSeen {
            cell.killedByLabel.text = "Killed by " + (thread.lastPostAuthorName ?? "")
            cell.unreadRepliesLabel.text = "\(thread.unreadPosts)"
        } else {
            cell.killedByLabel.text = "Posted by " + (thread.author?.username ?? "")
            cell.unreadRepliesLabel.text = nil
        }
        
        var accessibilityLabel = thread.title ?? ""
        if thread.beenSeen {
            accessibilityLabel += ", \(thread.unreadPosts) unread post\(sifplural(thread.unreadPosts))"
        }
        if thread.sticky {
            accessibilityLabel += ", sticky"
        }
        accessibilityLabel += ". \(thread.numberOfPages) page\(sifplural(thread.numberOfPages))"
        accessibilityLabel += ", \(cell.killedByLabel.text)"
        cell.accessibilityLabel = accessibilityLabel
        
        return cell
    }
    
    @objc private func showThreadActions(cell: ThreadCell) {
        let tableView: UITableView = cell.nearestSuperviewOfDeclaredType()
        if let indexPath = tableView.indexPathForCell(cell) {
            let thread = itemAtIndexPath(indexPath) as Thread
            showActionsForThread(thread, forTableView: tableView)
        }
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

extension Int {
    func clamp<T: IntervalType where T.Bound == Int>(interval: T) -> Int {
        if self < interval.start {
            return interval.start
        } else if self > interval.end {
            return interval.end
        } else {
            return self
        }
    }
}

func nonempty(s: String?) -> String? {
    if let s = s {
        return s.isEmpty ? nil : s
    } else {
        return s
    }
}

func sifplural(i: Int32) -> String {
    return i == 1 ? "" : "s"
}
