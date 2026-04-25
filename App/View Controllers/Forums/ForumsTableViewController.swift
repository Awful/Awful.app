//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import os
import UIKit
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsTableViewController")

final class ForumsTableViewController: CollectionViewController {

    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    private var favoriteForumCountObserver: ManagedObjectCountObserver!
    private var listDataSource: ForumListDataSource!
    let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showUnreadAnnouncementsBadge) private var showUnreadAnnouncementsBadge
    private var unreadAnnouncementCountObserver: ManagedObjectCountObserver!
    private var cellRegistration: UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView>!

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(collectionViewLayout: ForumsTableViewController.makeLayout(separatorLeadingInset: tableSeparatorLeftMargin, separatorColor: nil, swipeActionsProvider: nil))

        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")

        favoriteForumCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: ForumMetadata.entityName,
            predicate: NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite)),
            didChange: { [weak self] favoriteCount in
                guard let self else { return }
                updateEditingState(favoriteCount: favoriteCount)
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        })
        updateEditingState(favoriteCount: favoriteForumCountObserver.count)

        unreadAnnouncementCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: Announcement.entityName,
            predicate: NSPredicate(format: "%K == NO", #keyPath(Announcement.hasBeenSeen)),
            didChange: { [weak self] unreadCount in
                self?.updateBadgeValue(unreadCount) })

        $showUnreadAnnouncementsBadge
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                updateBadgeValue(unreadAnnouncementCountObserver.count)
            }
            .store(in: &cancellables)

        cellRegistration = makeCellRegistration()
        headerRegistration = makeHeaderRegistration()

        themeDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout(
        separatorLeadingInset: CGFloat,
        separatorColor: UIColor?,
        swipeActionsProvider: ((IndexPath) -> UISwipeActionsConfiguration?)?
    ) -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
        config.headerMode = .supplementary
        config.backgroundColor = .clear

        var separatorConfig = UIListSeparatorConfiguration(listAppearance: .plain)
        separatorConfig.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: separatorLeadingInset, bottom: 0, trailing: 0)
        if let separatorColor {
            separatorConfig.color = separatorColor
        }
        config.separatorConfiguration = separatorConfig

        if let swipeActionsProvider {
            config.trailingSwipeActionsConfigurationProvider = { indexPath in
                swipeActionsProvider(indexPath)
            }
        }

        return CollectionViewController.makeListLayout(using: config)
    }

    private func rebuildLayout() {
        let layout = ForumsTableViewController.makeLayout(
            separatorLeadingInset: tableSeparatorLeftMargin,
            separatorColor: theme[uicolor: "listSeparatorColor"],
            swipeActionsProvider: { [weak self] indexPath in
                self?.swipeActionsConfig(at: indexPath)
            }
        )
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    private func swipeActionsConfig(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard listDataSource?.canEditItem(at: indexPath) == true else { return nil }
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            self?.listDataSource.deleteFavorite(at: indexPath)
            completion(true)
        }
        action.image = UIImage(systemName: "star.slash")
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func makeCellRegistration() -> UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item> {
        UICollectionView.CellRegistration<ForumListCell, ForumListDataSource.Item> { [weak self] cell, _, item in
            guard let self else { return }
            cell.viewModel = self.listDataSource.viewModelFor(item: item)
            cell.didTapExpand = { [weak self] in
                self?.didTapDisclosureButton(in: $0)
            }
            cell.didTapFavorite = { [weak self] in
                self?.didTapStarButton(in: $0)
            }
            // Show the inline delete accessory for favorite-forum rows in edit mode.
            if case .favoriteForum = item {
                cell.accessories = [.delete(displayed: .whenEditing, actionHandler: { [weak self, weak cell] in
                    guard let self,
                          let cell,
                          let path = self.collectionView.indexPath(for: cell)
                    else { return }
                    self.listDataSource.deleteFavorite(at: path)
                })]
            } else {
                cell.accessories = []
            }
        }
    }

    private func makeHeaderRegistration() -> UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView> {
        UICollectionView.SupplementaryRegistration<ForumListSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            guard let self else { return }
            header.viewModel = .init(
                backgroundColor: self.theme["listHeaderBackgroundColor"],
                font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular),
                sectionName: self.listDataSource.titleForSection(indexPath.section),
                textColor: self.theme["listHeaderTextColor"])
        }
    }

    private func refreshIfNecessary() {
        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) {
            refresh()
        }
    }

    private func refresh() {
        Task {
            do {
                try await ForumsClient.shared.taxonomizeForums()
                RefreshMinder.sharedMinder.didRefresh(.forumList)
                migrateFavoriteForumsFromSettings()
            } catch {
                logger.error("Could not taxonomize forums: \(error)")
            }

            stopAnimatingPullToRefresh()
        }
    }

    private func migrateFavoriteForumsFromSettings() {
        // TODO: this shouldn't be the view controller's responsibility.
        // In Awful 3.2, favorite forums moved from UserDefaults to the ForumMetadata entity in Core Data.
        if let forumIDs = SettingsMigration.favoriteForums(.standard) {
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs: forumIDs.map(\.rawValue), in: managedObjectContext)
            for (i, metadata) in zip(0..., metadatas) {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            do {
                try managedObjectContext.save()
            }
            catch {
                fatalError("error saving: \(error)")
            }
            SettingsMigration.forgetFavoriteForums(.standard)
        }
    }

    private func updateBadgeValue(_ unreadCount: Int) {
        tabBarItem?.badgeValue = {
            guard showUnreadAnnouncementsBadge else { return nil }

            return unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }()
    }

    private func updateEditingState(favoriteCount: Int) {
        navigationItem.setLeftBarButton(favoriteCount > 0 ? editButtonItem : nil, animated: true)

        if isEditing, favoriteCount == 0 {
            setEditing(false, animated: true)
        }
    }

    func openForum(_ forum: Forum, animated: Bool) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let threadList = ThreadsTableViewController(forum: forum)
        navigationController?.pushViewController(threadList, animated: animated)
    }

    func openAnnouncement(_ announcement: Announcement) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let vc = AnnouncementViewController(announcement: announcement)
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

        listDataSource = try! ForumListDataSource(
            managedObjectContext: managedObjectContext,
            collectionView: collectionView,
            cellRegistration: cellRegistration,
            supplementaryViewProvider: { [weak self] cv, kind, indexPath in
                guard let self, kind == UICollectionView.elementKindSectionHeader else { return nil }
                return cv.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            }
        )
        listDataSource.delegate = self

        // Now that the data source exists, rebuild the layout with a swipe-actions
        // provider that consults it.
        rebuildLayout()

        // 14pt of bottom breathing room — equivalent of the old tableFooterView trick.
        collectionView.contentInset.bottom = tableBottomMargin

        pullToRefreshBlock = { [weak self] in
            self?.refresh()
        }

        lazy var searchButton: UIBarButtonItem = {
            let button = UIBarButtonItem(title: "Search", style: .plain, target: self, action: #selector(searchForums))
            button.isEnabled = canSendPrivateMessages
            return button
        }()

        if canSendPrivateMessages {
            navigationItem.setRightBarButton(searchButton, animated: true)
        }

        $canSendPrivateMessages
            .receive(on: RunLoop.main)
            .sink { [weak self] canSend in
                guard let self else { return }
                if canSend {
                    navigationItem.setRightBarButton(searchButton, animated: true)
                } else {
                    navigationItem.setRightBarButton(nil, animated: true)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func searchForums() {
        let searchView = SearchHostingController()
        if traitCollection.userInterfaceIdiom == .pad {
            searchView.modalPresentationStyle = .pageSheet
        } else {
            searchView.modalPresentationStyle = .fullScreen
        }
        present(searchView, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Reset the cached width when the collection view's width changes so any
        // stale heights computed against the old width get re-measured.
        let currentWidth = collectionView.bounds.width
        if let last = ForumListCell.lastKnownContentViewWidth, abs(last - currentWidth) > 1 {
            ForumListCell.lastKnownContentViewWidth = nil
        }
    }

    override func themeDidChange() {
        if isViewLoaded {
            rebuildLayout()
        }

        super.themeDidChange()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = editing
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

    private func didTapDisclosureButton(in cell: UICollectionViewCell) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let indexPath = collectionView.indexPath(for: cell),
              let forum = listDataSource.item(at: indexPath) as? Forum
        else { return }

        if forum.metadata.showsChildrenInForumList {
            forum.collapse()
        } else {
            forum.expand()
        }

        try! forum.managedObjectContext!.save()
    }

    private func didTapStarButton(in cell: UICollectionViewCell) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let indexPath = collectionView.indexPath(for: cell),
              let forum = listDataSource.item(at: indexPath) as? Forum
        else { return }

        if forum.metadata.favorite {
            forum.metadata.favorite = false
        } else {
            forum.metadata.favorite = true
            forum.metadata.favoriteIndex = listDataSource.nextFavoriteIndex
        }
        forum.tickleForFetchedResultsController()

        try! forum.managedObjectContext!.save()
    }
}

private let tableBottomMargin: CGFloat = 14
private let tableSeparatorLeftMargin: CGFloat = 46

extension ForumsTableViewController: ForumListDataSourceDelegate {
    func themeForCells(in dataSource: ForumListDataSource) -> Theme {
        return theme
    }
}

// MARK: UICollectionViewDelegate
extension ForumsTableViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch listDataSource.item(at: indexPath) {
        case let announcement as Announcement:
            openAnnouncement(announcement)

        case let forum as Forum:
            openForum(forum, animated: true)

        default:
            assertionFailure("unknown object type in forums list")
        }
    }

    override func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return listDataSource.proposedTargetIndexPath(for: originalIndexPath, proposed: proposedIndexPath)
    }
}

extension ForumsTableViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .forumList
    }
}
