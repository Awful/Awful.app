//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

final class ForumsTableViewController: TableViewController {
    
    private var favoriteForumCountObserver: ManagedObjectCountObserver!
    private var listDataSource: ForumListDataSource!
    let managedObjectContext: NSManagedObjectContext
    private var observers: [NSKeyValueObservation] = []
    private var unreadAnnouncementCountObserver: ManagedObjectCountObserver!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .grouped)
        
        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")

        favoriteForumCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: ForumMetadata.entityName(),
            predicate: NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite)),
            didChange: { [weak self] favoriteCount in
                self?.updateEditingState(favoriteCount: favoriteCount)
        })
        updateEditingState(favoriteCount: favoriteForumCountObserver.count)

        unreadAnnouncementCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: Announcement.entityName(),
            predicate: NSPredicate(format: "%K == NO", #keyPath(Announcement.hasBeenSeen)),
            didChange: { [weak self] unreadCount in
                self?.updateBadgeValue(unreadCount) })
        updateBadgeValue(unreadAnnouncementCountObserver.count)
        
        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.showUnreadAnnouncementsBadge) { [unowned self] defaults in
                self.updateBadgeValue(self.unreadAnnouncementCountObserver.count)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func refreshIfNecessary() {
        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) {
            refresh()
        }
    }
    
    private func refresh() {
        _ = ForumsClient.shared.taxonomizeForums()
            .done { forums in
                RefreshMinder.sharedMinder.didRefresh(.forumList)
                self.migrateFavoriteForumsFromSettings()
            }
            .ensure { self.stopAnimatingPullToRefresh() }
    }
    
    private func migrateFavoriteForumsFromSettings() {
        // TODO: this shouldn't be the view controller's responsibility.
        // In Awful 3.2 favorite forums moved from AwfulSettings (i.e. NSUserDefaults) to the ForumMetadata entity in Core Data.
        if let forumIDs = AwfulSettings.shared().favoriteForums {
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
    
    private func updateBadgeValue(_ unreadCount: Int) {
        tabBarItem?.badgeValue = {
            guard UserDefaults.standard.showUnreadAnnouncementsBadge else { return nil }
            
            return unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }()
    }

    private func updateEditingState(favoriteCount: Int) {
        navigationItem.setRightBarButton(favoriteCount > 0 ? editButtonItem : nil, animated: true)

        if isEditing, favoriteCount == 0 {
            setEditing(false, animated: true)
        }
    }
    
    func openForum(_ forum: Forum, animated: Bool) {
        let threadList = ThreadsTableViewController(forum: forum)
        threadList.restorationClass = ThreadsTableViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }

    func openAnnouncement(_ announcement: Announcement) {
        let vc = AnnouncementViewController(announcement: announcement)
        vc.restorationIdentifier = "Announcement"
        showDetailViewController(vc, sender: self)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override var undoManager: UndoManager? {
        return listDataSource.undoManager
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(ForumListSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeader.reuseIdentifier)
        tableView.restorationIdentifier = "Forums table"
        tableView.sectionFooterHeight = 0
        tableView.separatorInset.left = tableSeparatorLeftMargin
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: tableBottomMargin))

        listDataSource = try! ForumListDataSource(managedObjectContext: managedObjectContext, tableView: tableView)
        tableView.reloadData()
        
        pullToRefreshBlock = { [weak self] in
            self?.refresh()
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        refreshIfNecessary()

        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        resignFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        undoManager?.removeAllActions()
    }
    
    // MARK: Actions

    private func didTapDisclosureButton(in cell: UITableViewCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let forum = listDataSource.item(at: indexPath) as? Forum
            else { return }

        if forum.metadata.showsChildrenInForumList {
            forum.collapse()
        }
        else {
            forum.expand()
        }
        
        try! forum.managedObjectContext!.save()
    }

    private func didTapStarButton(in cell: UITableViewCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let forum = listDataSource.item(at: indexPath) as? Forum
            else { return }

        if forum.metadata.favorite {
            forum.metadata.favorite = false
        }
        else {
            forum.metadata.favorite = true
            forum.metadata.favoriteIndex = listDataSource.nextFavoriteIndex
        }
        forum.tickleForFetchedResultsController()

        try! forum.managedObjectContext!.save()
    }
}

private let tableBottomMargin: CGFloat = 14
private let tableSeparatorLeftMargin: CGFloat = 46

extension ForumsTableViewController {
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView.dataSource?.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return 0
        }
        else {
            return SectionHeader.height
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeader.reuseIdentifier) as? ForumListSectionHeaderView else {
            assertionFailure("where's the header")
            return nil
        }

        header.viewModel = .init(
            backgroundColor: theme["listHeaderBackgroundColor"],
            font: UIFont.preferredFont(forTextStyle: .body),
            sectionName: listDataSource.titleForSection(section),
            textColor: theme["listHeaderTextColor"])

        return header
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return listDataSource.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? ForumListCell {
            cell.didTapExpand = { [weak self] in
                self?.didTapDisclosureButton(in: $0)
            }
            
            cell.didTapFavorite = { [weak self] in
                self?.didTapStarButton(in: $0)
            }
        }
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        return listDataSource.tableView(tableView, targetIndexPathForMoveFromRowAt: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch listDataSource.item(at: indexPath) {
        case let announcement as Announcement:
            openAnnouncement(announcement)

        case let forum as Forum:
            openForum(forum, animated: true)

        default:
            assertionFailure("unknown object type in forums list")
        }
    }
}

private enum SectionHeader {
    static let height: CGFloat = 44
    static let reuseIdentifier = "Header"
}
