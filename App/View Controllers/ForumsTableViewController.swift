//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

final class ForumsTableViewController: TableViewController {
    let managedObjectContext: NSManagedObjectContext
    private var dataSource: ForumTableViewDataSource!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .Plain)
        
        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func refreshIfNecessary() {
        if RefreshMinder.sharedMinder.shouldRefresh(.ForumList) || dataSource.isEmpty {
            refresh()
        }
    }
    
    private func refresh() {
        AwfulForumsClient.sharedClient().taxonomizeForumsAndThen { (error: NSError?, forums: [AnyObject]?) in
            if error == nil {
                RefreshMinder.sharedMinder.didRefresh(.ForumList)
                self.migrateFavoriteForumsFromSettings()
            }
            self.stopAnimatingPullToRefresh()
        }
    }
    
    private func migrateFavoriteForumsFromSettings() {
        // In Awful 3.2 favorite forums moved from AwfulSettings (i.e. NSUserDefaults) to the ForumMetadata entity in Core Data.
        if let forumIDs = AwfulSettings.sharedSettings().favoriteForums as! [String]? {
            AwfulSettings.sharedSettings().favoriteForums = nil
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs, inManagedObjectContext: managedObjectContext)
            for (i, metadata) in metadatas.enumerate() {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            do {
                try managedObjectContext.save()
            }
            catch {
                fatalError("error saving: \(error)")
            }
        }
    }
    
    func openForum(forum: Forum, animated: Bool) {
        let threadList = ThreadsTableViewController(forum: forum)
        threadList.restorationClass = ThreadsTableViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }
    
    private func updateEditButtonPresence(animated animated: Bool) {
        navigationItem.setRightBarButtonItem(dataSource.hasFavorites ? editButtonItem() : nil, animated: animated)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerNib(UINib(nibName: ForumTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ForumTableViewCell.identifier)
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: ForumTableViewDataSource.headerReuseIdentifier)
        
        tableView.estimatedRowHeight = ForumTableViewCell.estimatedRowHeight
        tableView.separatorStyle = .None
        
        let cellConfigurator: (ForumTableViewCell, Forum, ForumTableViewCell.ViewModel) -> Void = { [weak self] cell, forum, viewModel in
            cell.viewModel = viewModel
            cell.starButtonAction = self?.didTapStarButton
            cell.disclosureButtonAction = self?.didTapDisclosureButton
            
            guard let theme = self?.theme else { return }
            cell.themeData = ForumTableViewCell.ThemeData(theme)
        }
        let headerThemer: UITableViewCell -> Void = { [weak self] cell in
            guard let theme = self?.theme else { return }
            cell.textLabel?.textColor = theme["listHeaderTextColor"]
            cell.backgroundColor = theme["listHeaderBackgroundColor"]
            cell.selectedBackgroundColor = theme["listHeaderBackgroundColor"]
        }
        dataSource = ForumTableViewDataSource(tableView: tableView, managedObjectContext: managedObjectContext, cellConfigurator: cellConfigurator, headerThemer: headerThemer)
        tableView.dataSource = dataSource
        
        dataSource.didReload = { [weak self] in
            self?.updateEditButtonPresence(animated: false)
            
            if self?.editing == true && self?.dataSource.hasFavorites == false {
                dispatch_async(dispatch_get_main_queue()) {
                    // The docs say not to call this from an implementation of UITableViewDataSource.tableView(_:commitEditingStyle:forRowAtIndexPath:), but if you must, do a delayed perform.
                    self?.setEditing(false, animated: true)
                }
            }
        }
        
        updateEditButtonPresence(animated: false)
        
        pullToRefreshBlock = { [weak self] in
            self?.refresh()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshIfNecessary()
    }
    
    // MARK: Actions
    
    private func didTapStarButton(cell: ForumTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("tapped star button in header?") }
        forum.metadata.favoriteIndex = dataSource.lastFavoriteIndex.map { $0 + 1 } ?? 0
        forum.metadata.favorite = !forum.metadata.favorite
        try! forum.managedObjectContext!.save()
    }
    
    private func didTapDisclosureButton(cell: ForumTableViewCell) {
        guard let indexPath = tableView.indexPathForCell(cell) else { return }
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("tapped disclosure button in header?") }
        forum.metadata.showsChildrenInForumList = !forum.metadata.showsChildrenInForumList
        try! forum.managedObjectContext!.save()
    }
}

extension ForumsTableViewController {
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        guard case .Some = dataSource.objectAtIndexPath(indexPath) else { return nil }
        return indexPath
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("shouldn't be selecting a header cell") }
        openForum(forum, animated: true)
    }
    
    override func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath toIndexPath: NSIndexPath) -> NSIndexPath {
        guard let lastFavoriteIndex = dataSource.lastFavoriteIndex else { fatalError("asking for target index path for non-favorite") }
        let targetRow = min(toIndexPath.row, lastFavoriteIndex)
        return NSIndexPath(forRow: targetRow, inSection: 0)
    }
}

extension ForumTableViewCell.ThemeData {
    init(_ theme: Theme) {
        nameColor = theme["listTextColor"]!
        backgroundColor = theme["listBackgroundColor"]!
        selectedBackgroundColor = theme["listSelectedBackgroundColor"]!
        separatorColor = theme["listSeparatorColor"]!
    }
}
