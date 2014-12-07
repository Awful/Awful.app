//  ForumListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ForumListViewController)
class ForumListViewController: AwfulTableViewController {
    let managedObjectContext: NSManagedObjectContext
    private let dataSource: DataSource
    private let favoriteDataSource: ForumFavoriteDataSource
    private let treeDataSource: ForumTreeDataSource
    private let contextObserver: ForumContextObserver!

    required init(coder: NSCoder) {
        managedObjectContext = AwfulAppDelegate.instance().managedObjectContext
        favoriteDataSource = ForumFavoriteDataSource(managedObjectContext: managedObjectContext)
        treeDataSource = ForumTreeDataSource(managedObjectContext: managedObjectContext)
        dataSource = CompoundDataSource(favoriteDataSource, treeDataSource)
        super.init(coder: coder)
        dataSource.delegate = self
        
        // Since the data sources work on ForumMetadata entities, it won't pick up any changes to the names of the forums. We'll handle that here.
        contextObserver = ForumContextObserver(managedObjectContext: managedObjectContext) { [unowned self] forums in
            if self.editing {
                // Don't do anything if we're rearranging favorites. It's the same issue mentioned by the comment in dataSource(_:performBatchUpdates:completion:).
                return
            }
            self.tableView.beginUpdates()
            for forum in forums {
                let indexPaths = self.dataSource.indexPathsForItem(forum.metadata)
                self.dataSource(self.dataSource, didRefreshItemsAtIndexPaths: indexPaths)
            }
            self.tableView.endUpdates()
        }
        
        navigationItem.backBarButtonItem = UIBarButtonItem.awful_emptyBackBarButtonItem()
    }
    
    class func newFromStoryboard() -> ForumListViewController {
        return UIStoryboard(name: "ForumList", bundle: nil).instantiateInitialViewController() as ForumListViewController
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
            let userInfo = notification.userInfo as [String:AnyObject]
            let changedObjects = NSMutableSet()
            for key in [NSUpdatedObjectsKey, NSRefreshedObjectsKey] {
                if let updated = userInfo[key] as NSSet? {
                    changedObjects.unionSet(updated)
                }
            }
            let forums = filter(changedObjects) { ($0 as NSManagedObject).entity == self.entity } as [Forum]
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

        tableView.registerClass(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: headerIdentifier)
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
        if let forumIDs = AwfulSettings.sharedSettings().favoriteForums as [String]? {
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
        let metadata = dataSource.itemAtIndexPath(indexPath) as ForumMetadata
        metadata.showsChildrenInForumList = sender.selected
        metadata.updateSubtreeVisibility()
    }
    
    @IBAction private func didTapFavoriteStar(sender: UIButton) {
        let cell: UITableViewCell = sender.nearestSuperviewOfDeclaredType()
        let indexPath = tableView.indexPathForCell(cell)!
        let metadata = dataSource.itemAtIndexPath(indexPath) as ForumMetadata
        metadata.favoriteIndex = Int32(favoriteDataSource.fetchedResultsController.fetchedObjects?.count ?? 0)
        metadata.favorite = true
        
        // Trigger a refresh for just this cell.
        metadata.willChangeValueForKey("visibleInForumList")
        metadata.didChangeValueForKey("visibleInForumList")
    }

    func openForum(forum: Forum, animated: Bool) {
        let threadList = ThreadListViewController(forum: forum)
        threadList.restorationClass = ThreadListViewController.self
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
                return currentView as T
            } else {
                currentView = currentView.superview
            }
        }
        fatalError("could not find superview of type \(T.self)")
    }
}

extension ForumMetadata {
    func updateSubtreeVisibility() {
        let childMetadatas = map(forum.childForums) { ($0 as Forum).metadata }
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
        let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier(headerIdentifier) as UITableViewHeaderFooterView
        header.textLabel.text = dataSource.tableView?(tableView, titleForHeaderInSection: section)
        return header
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel.textColor = theme["listHeaderTextColor"] as UIColor?
            header.contentView.backgroundColor = theme["listHeaderBackgroundColor"] as UIColor?
            header.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
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
            cell.nameLabel.textColor = theme["listTextColor"] as UIColor?
            cell.backgroundColor = theme["listBackgroundColor"] as UIColor?
            cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"] as UIColor?
            if indexPath.row + 1 == tableView.numberOfRowsInSection(indexPath.section) {
                cell.separator.backgroundColor = cell.backgroundColor
            } else {
                cell.separator.backgroundColor = theme["listSeparatorColor"] as UIColor?
            }
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let metadata = dataSource.itemAtIndexPath(indexPath) as ForumMetadata
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
    func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Top)
    }
    
    func dataSource(dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
    }
    
    func dataSource(dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet) {
        tableView.insertSections(sections, withRowAnimation: .Top)
    }
    
    func dataSource(dataSource: DataSource, didRemoveSections sections: NSIndexSet) {
        tableView.deleteSections(sections, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet) {
        tableView.reloadSections(sections, withRowAnimation: .None)
    }
    
    func dataSource(dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int) {
        tableView.moveSection(fromSection, toSection: toSection)
    }
    
    func dataSourceDidReloadData(dataSource: DataSource) {
        tableView.reloadData()
    }
    
    func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
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
