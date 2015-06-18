//  ForumListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ForumListViewController)
class ForumListViewController: AwfulTableViewController {
    let managedObjectContext: NSManagedObjectContext
    private let dataSource: DataSource
    private let favoriteDataSource: ForumFavoriteDataSource
    private let treeDataSource: ForumTreeDataSource
    private var contextObserver: ForumContextObserver!

    required init(coder: NSCoder) {
        managedObjectContext = AwfulAppDelegate.instance().managedObjectContext
        favoriteDataSource = ForumFavoriteDataSource(managedObjectContext: managedObjectContext)
        treeDataSource = ForumTreeDataSource(managedObjectContext: managedObjectContext)
        dataSource = CompoundDataSource(favoriteDataSource, treeDataSource)
        super.init(coder: coder)
        
        dataSource.delegate = self
        
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")
        
        // Since the data sources work on ForumMetadata entities, it won't pick up any changes to the names of the forums. We'll handle that here.
        contextObserver = ForumContextObserver(managedObjectContext: managedObjectContext) { [unowned self] forums in
            if self.editing {
                // Don't do anything if we're rearranging favorites. It's the same issue mentioned by the comment in dataSource(_:performBatchUpdates:completion:).
                return
            }
            
            if forums.count <= 4 {
                self.tableView.beginUpdates()
                for forum in forums {
                    let indexPaths = self.dataSource.indexPathsForItem(forum.metadata)
                    self.dataSource(self.dataSource, didRefreshItemsAtIndexPaths: indexPaths)
                }
                self.tableView.endUpdates()
            } else {
                self.tableView.reloadData()
            }
        }
    }
    
    class func newFromStoryboard() -> ForumListViewController {
        return UIStoryboard(name: "ForumList", bundle: nil).instantiateInitialViewController() as! ForumListViewController
    }
    
    private class ForumContextObserver: NSObject {
        let managedObjectContext: NSManagedObjectContext
        let entity: NSEntityDescription
        let changeBlock: [Forum] -> Void
        
        init(managedObjectContext context: NSManagedObjectContext, changeBlock: [Forum] -> Void) {
            managedObjectContext = context
            entity = NSEntityDescription.entityForName(Forum.entityName(), inManagedObjectContext: context)!
            self.changeBlock = changeBlock
            super.init()
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "objectsDidChange:", name: NSManagedObjectContextObjectsDidChangeNotification, object: context)
        }
        
        deinit {
            NSNotificationCenter.defaultCenter().removeObserver(self)
        }
        
        @objc private func objectsDidChange(notification: NSNotification) {
            let userInfo = notification.userInfo as! [String:AnyObject]
            var changedObjects = Set<NSManagedObject>()
            for key in [NSUpdatedObjectsKey, NSRefreshedObjectsKey] {
                if let updated = userInfo[key] as! Set<NSManagedObject>? {
                    changedObjects.unionInPlace(updated)
                }
            }
            let forums = filter(changedObjects) { $0.entity == self.entity } as! [Forum]
            if !forums.isEmpty {
                changeBlock(forums)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Can only get down to 1 in IB. Pretend that means 0.
        if tableView.sectionHeaderHeight == 1 {
            tableView.sectionHeaderHeight = 0
        }
        if tableView.sectionFooterHeight == 1 {
            tableView.sectionFooterHeight = 0
        }

        tableView.registerClass(ForumListSectionHeader.self, forHeaderFooterViewReuseIdentifier: headerIdentifier)
        tableView.dataSource = dataSource
        
        updateEditButtonPresence(animated: false)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshIfNecessary()
    }
    
    private func refreshIfNecessary() {
        if AwfulRefreshMinder.sharedMinder().shouldRefreshForumList() || dataSource.numberOfSections == 0 {
            refresh()
        }
    }
    
    @IBAction private func refresh() {
        AwfulForumsClient.sharedClient().taxonomizeForumsAndThen { error, forums in
            if error == nil {
                AwfulRefreshMinder.sharedMinder().didFinishRefreshingForumList()
                self.migrateFavoriteForumsFromSettings()
            }
            self.refreshControl?.endRefreshing()
        }
    }
    
    private func migrateFavoriteForumsFromSettings() {
        // In Awful 3.2 favorite forums moved from AwfulSettings (i.e. NSUserDefaults) to the ForumMetadata entity in Core Data.
        if let forumIDs = AwfulSettings.sharedSettings().favoriteForums as! [String]? {
            AwfulSettings.sharedSettings().favoriteForums = nil
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs, inManagedObjectContext: managedObjectContext)
            for (i, metadata) in enumerate(metadatas) {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            var error: NSError?
            if !managedObjectContext.save(&error) {
                fatalError("error saving: \(error)")
            }
        }
    }
    
    @IBAction private func didToggleShowingChildren(sender: UIButton) {
        sender.selected = !sender.selected
        let cell: UITableViewCell = sender.nearestSuperviewOfDeclaredType()
        let indexPath = tableView.indexPathForCell(cell)!
        let metadata = dataSource.itemAtIndexPath(indexPath) as! ForumMetadata
        metadata.showsChildrenInForumList = sender.selected
        metadata.updateSubtreeVisibility()
    }
    
    @IBAction private func didTapFavoriteStar(sender: UIButton) {
        let cell: UITableViewCell = sender.nearestSuperviewOfDeclaredType()
        let indexPath = tableView.indexPathForCell(cell)!
        let metadata = dataSource.itemAtIndexPath(indexPath) as! ForumMetadata
        metadata.favoriteIndex = Int32(favoriteDataSource.fetchedResultsController.fetchedObjects?.count ?? 0)
        metadata.favorite = true
        
        // Trigger a refresh for just this cell.
        metadata.willChangeValueForKey("visibleInForumList")
        metadata.didChangeValueForKey("visibleInForumList")
    }

    func openForum(forum: Forum, animated: Bool) {
        let threadList = ForumSpecificThreadListViewController(forum: forum)
        threadList.restorationClass = ForumSpecificThreadListViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        // Since animating table changes while we rearrange favorites causes problems, we'll just do a full reload when we stop rearranging favorites. If we're animating the end of editing, we'll do it after the animation. Otherwise we'll just do it at the end.
        let reloadBlock = { self.tableView.reloadData() }
        if animated && !editing {
            CATransaction.begin()
            CATransaction.setCompletionBlock(reloadBlock)
        }
        
        super.setEditing(editing, animated: animated)
        updateEditButtonPresence(animated: animated)
        
        if !editing {
            if animated {
                CATransaction.commit()
            } else {
                reloadBlock()
            }
        }
    }
    
    private func updateEditButtonPresence(#animated: Bool) {
        navigationItem.setRightBarButtonItem(favoriteDataSource.numberOfSections > 0 ? editButtonItem() : nil, animated: animated)
    }
}

extension UIView {
    func nearestSuperviewOfDeclaredType<T: UIView>() -> T {
        var currentView: UIView! = self
        while currentView != nil {
            // `if currentView is T` doesn't work here and I'm not sure why (T seems to get stuck as UIView somehow and self.superview is invariably returned).
            if currentView.isKindOfClass(T) {
                return currentView as! T
            } else {
                currentView = currentView.superview
            }
        }
        fatalError("could not find superview of type \(T.self)")
    }
}

extension ForumMetadata {
    func updateSubtreeVisibility() {
        let childMetadatas = map(forum.childForums) { ($0 as! Forum).metadata }
        for child in childMetadatas {
            if showsChildrenInForumList {
                child.visibleInForumList = visibleInForumList
            } else {
                child.visibleInForumList = false
            }
            child.updateSubtreeVisibility()
        }
    }
}

extension ForumListViewController: UITableViewDelegate {
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier(headerIdentifier) as! ForumListSectionHeader
        header.sectionNameLabel.text = dataSource.tableView?(tableView, titleForHeaderInSection: section)
        return header
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? ForumListSectionHeader {
            header.sectionNameLabel.textColor = theme["listHeaderTextColor"]
            header.contentView.backgroundColor = theme["listHeaderBackgroundColor"]
            header.sectionNameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            header.textLabel.text = ""
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UIFont.preferredFontForTextStyle(UIFontTextStyleBody).pointSize * 2
    }
    
    override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        // This method is implemented not for scrolling efficiency but because a missing implementation wreaks havoc on cell heights when expanding or collapsing a forum's subforums.
        return ForumCell.minimumHeight()
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = cell as? ForumCell {
            cell.nameLabel.textColor = theme["listTextColor"]
            cell.backgroundColor = theme["listBackgroundColor"]
            cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
            if indexPath.row + 1 == tableView.numberOfRowsInSection(indexPath.section) {
                cell.separator.backgroundColor = cell.backgroundColor
            } else {
                cell.separator.backgroundColor = theme["listSeparatorColor"]
            }
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let metadata = dataSource.itemAtIndexPath(indexPath) as! ForumMetadata
        openForum(metadata.forum, animated: true)
    }
    
    override func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String! {
        return dataSource.tableView?(tableView, titleForDeleteConfirmationButtonForRowAtIndexPath: indexPath)
    }
    
    override func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
        return dataSource.tableView?(tableView, targetIndexPathForMoveFromRowAtIndexPath: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath) ?? proposedDestinationIndexPath
    }
}

private let headerIdentifier = "Header"

extension ForumListViewController: DataSourceDelegate {
    override func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Top)
    }
    
    override func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
    }

    override func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet) {
        tableView.insertSections(sections, withRowAnimation: .Top)
    }
    
    override func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet) {
        tableView.reloadSections(sections, withRowAnimation: .None)
    }
    
    override func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        if !visible { return }
        
        // Moving favorites around triggers updates to the tree part of the table. Unfortunately, if we perform those updates while the moved rows are animating, the rows involved in the move get horribly deformed. This is a pretty stupid workaround, but here we are: don't bother updating the table if we're editing. We'll reload the table once we're done rearranging favorites.
        if !editing {
            tableView.beginUpdates()
            updates()
            tableView.endUpdates()
        }
        completion?()
        
        if favoriteDataSource.numberOfSections == 0 {
            setEditing(false, animated: true)
        } else {
            updateEditButtonPresence(animated: true)
        }
    }
}
