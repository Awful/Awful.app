//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

final class ForumsTableViewController: TableViewController {
    let managedObjectContext: NSManagedObjectContext
    fileprivate var dataSource: ForumTableViewDataSource!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .plain)
        
        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func refreshIfNecessary() {
        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) || dataSource.isEmpty {
            refresh()
        }
    }
    
    fileprivate func refresh() {
        AwfulForumsClient.shared().taxonomizeForumsAndThen { (error: Error?, forums: [Any]?) in
            if error == nil {
                RefreshMinder.sharedMinder.didRefresh(.forumList)
                self.migrateFavoriteForumsFromSettings()
            }
            self.stopAnimatingPullToRefresh()
        }
    }
    
    fileprivate func migrateFavoriteForumsFromSettings() {
        // In Awful 3.2 favorite forums moved from AwfulSettings (i.e. NSUserDefaults) to the ForumMetadata entity in Core Data.
        if let forumIDs = AwfulSettings.shared().favoriteForums as! [String]? {
            AwfulSettings.shared().favoriteForums = nil
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs: forumIDs, inManagedObjectContext: managedObjectContext)
            for (i, metadata) in metadatas.enumerated() {
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
    
    func openForum(_ forum: Forum, animated: Bool) {
        let threadList = ThreadsTableViewController(forum: forum)
        threadList.restorationClass = ThreadsTableViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }
    
    fileprivate func updateEditButtonPresence(animated: Bool) {
        navigationItem.setRightBarButton(dataSource.hasFavorites ? editButtonItem : nil, animated: animated)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: ForumTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ForumTableViewCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ForumTableViewDataSource.headerReuseIdentifier)
        
        tableView.estimatedRowHeight = ForumTableViewCell.estimatedRowHeight
        tableView.separatorStyle = .none
        
        let cellConfigurator: (ForumTableViewCell, Forum, ForumTableViewCell.ViewModel) -> Void = { [weak self] cell, forum, viewModel in
            cell.viewModel = viewModel
            cell.starButtonAction = self?.didTapStarButton
            cell.disclosureButtonAction = self?.didTapDisclosureButton
            
            guard let theme = self?.theme else { return }
            cell.themeData = ForumTableViewCell.ThemeData(theme)
        }
        let headerThemer: (UITableViewCell) -> Void = { [weak self] cell in
            guard let theme = self?.theme else { return }
            cell.textLabel?.textColor = theme["listHeaderTextColor"]
            cell.backgroundColor = theme["listHeaderBackgroundColor"]
            cell.selectedBackgroundColor = theme["listHeaderBackgroundColor"]
        }
        dataSource = ForumTableViewDataSource(tableView: tableView, managedObjectContext: managedObjectContext, cellConfigurator: cellConfigurator, headerThemer: headerThemer)
        tableView.dataSource = dataSource
        
        dataSource.didReload = { [weak self] in
            self?.updateEditButtonPresence(animated: false)
            
            if self?.isEditing == true && self?.dataSource.hasFavorites == false {
                DispatchQueue.main.async {
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshIfNecessary()
    }
    
    // MARK: Actions
    
    fileprivate func didTapStarButton(_ cell: ForumTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("tapped star button in header?") }
        forum.metadata.favoriteIndex = dataSource.lastFavoriteIndex.map { $0 + 1 } ?? 0
        forum.metadata.favorite = !forum.metadata.favorite
        try! forum.managedObjectContext!.save()
    }
    
    fileprivate func didTapDisclosureButton(_ cell: ForumTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("tapped disclosure button in header?") }
        forum.metadata.showsChildrenInForumList = !forum.metadata.showsChildrenInForumList
        try! forum.managedObjectContext!.save()
    }
}

extension ForumsTableViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard case .some = dataSource.objectAtIndexPath(indexPath) else { return nil }
        return indexPath
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let forum = dataSource.objectAtIndexPath(indexPath) else { fatalError("shouldn't be selecting a header cell") }
        openForum(forum, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath toIndexPath: IndexPath) -> IndexPath {
        guard let lastFavoriteIndex = dataSource.lastFavoriteIndex else { fatalError("asking for target index path for non-favorite") }
        let targetRow = max(1, min((toIndexPath as NSIndexPath).row, lastFavoriteIndex))
        return IndexPath(row: targetRow, section: 0)
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
