//  ForumListDataSource.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import CoreData
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumListDataSource")

final class ForumListDataSource: NSObject {
    weak var delegate: ForumListDataSourceDelegate?

    private let announcementsController: NSFetchedResultsController<Announcement>
    private let favoriteForumsController: NSFetchedResultsController<ForumMetadata>
    private let forumsController: NSFetchedResultsController<Forum>

    private let collectionView: UICollectionView
    private var diffableDataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var ignoreControllerUpdates = false
    private var pendingSnapshotApply: DispatchWorkItem?

    private(set) lazy var undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()

    enum Section: Hashable {
        case announcements
        case favorites
        case forumGroup(String)
    }

    enum Item: Hashable {
        case announcement(NSManagedObjectID)
        case favoriteForum(NSManagedObjectID)
        case forum(NSManagedObjectID)
    }

    init(
        managedObjectContext: NSManagedObjectContext,
        collectionView: UICollectionView,
        cellRegistration: UICollectionView.CellRegistration<ForumListCell, Item>,
        supplementaryViewProvider: @escaping (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    ) throws {
        let announcementsRequest = Announcement.makeFetchRequest()
        announcementsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        announcementsController = NSFetchedResultsController(
            fetchRequest: announcementsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        let favoriteForumsRequest = ForumMetadata.makeFetchRequest()
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        favoriteForumsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        let forumsRequest = Forum.makeFetchRequest()
        forumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(Forum.metadata.visibleInForumList))
        forumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true),
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]
        forumsController = NSFetchedResultsController(
            fetchRequest: forumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: #keyPath(Forum.group.sectionIdentifier),
            cacheName: nil)

        self.collectionView = collectionView
        super.init()

        diffableDataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        diffableDataSource.supplementaryViewProvider = supplementaryViewProvider

        diffableDataSource.reorderingHandlers.canReorderItem = { item in
            if case .favoriteForum = item { return true }
            return false
        }
        diffableDataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            self?.applyReorderTransaction(transaction)
        }

        announcementsController.delegate = self
        favoriteForumsController.delegate = self
        forumsController.delegate = self

        try announcementsController.performFetch()
        try favoriteForumsController.performFetch()
        try forumsController.performFetch()

        applyCurrentSnapshot(animatingDifferences: false)

        NotificationCenter.default.addObserver(self, selector: #selector(dataStoreDidReset), name: .dataStoreDidReset, object: nil)
    }

    @objc private func dataStoreDidReset() {
        for controller in resultsControllers {
            do {
                try controller.performFetch()
            } catch {
                logger.error("Failed to re-fetch after data store reset: \(error)")
            }
        }
        applyCurrentSnapshot(animatingDifferences: false)
    }

    private var resultsControllers: [NSFetchedResultsController<NSFetchRequestResult>] {
        return [announcementsController as! NSFetchedResultsController<NSFetchRequestResult>,
                favoriteForumsController as! NSFetchedResultsController<NSFetchRequestResult>,
                forumsController as! NSFetchedResultsController<NSFetchRequestResult>]
    }

    private func applyCurrentSnapshot(animatingDifferences: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        if let announcements = announcementsController.fetchedObjects, !announcements.isEmpty {
            snapshot.appendSections([.announcements])
            snapshot.appendItems(announcements.map { Item.announcement($0.objectID) }, toSection: .announcements)
        }

        if let favorites = favoriteForumsController.fetchedObjects, !favorites.isEmpty {
            snapshot.appendSections([.favorites])
            snapshot.appendItems(favorites.map { Item.favoriteForum($0.objectID) }, toSection: .favorites)
        }

        if let sections = forumsController.sections {
            for sectionInfo in sections {
                let section = Section.forumGroup(sectionInfo.name)
                snapshot.appendSections([section])
                if let objects = sectionInfo.objects as? [Forum] {
                    snapshot.appendItems(objects.map { Item.forum($0.objectID) }, toSection: section)
                }
            }
        }

        diffableDataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func scheduleSnapshotApply() {
        // Multiple FRCs often fire updates in quick succession for the same context save
        // (e.g. favoriting a forum updates the favorites FRC AND the forums FRC). Coalesce
        // them into one apply per runloop tick so the diff calculates against the final
        // state and we don't get jittery animations.
        pendingSnapshotApply?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.applyCurrentSnapshot(animatingDifferences: true)
            self.pendingSnapshotApply = nil
        }
        pendingSnapshotApply = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    // MARK: - Public API

    /// - Returns: The `Announcement` or `Forum` at `indexPath`.
    func item(at indexPath: IndexPath) -> Any {
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else {
            fatalError("no item at \(indexPath)")
        }
        return objectFor(item: item)
    }

    func objectFor(item: Item) -> Any {
        let context = forumsController.managedObjectContext
        switch item {
        case .announcement(let id):
            return context.object(with: id) as! Announcement
        case .favoriteForum(let id):
            // Existing API returns the forum, not the metadata.
            let metadata = context.object(with: id) as! ForumMetadata
            return metadata.forum
        case .forum(let id):
            return context.object(with: id) as! Forum
        }
    }

    func titleForSection(_ section: Int) -> String {
        let snapshot = diffableDataSource.snapshot()
        guard section < snapshot.sectionIdentifiers.count else { return "" }
        let sectionId = snapshot.sectionIdentifiers[section]
        switch sectionId {
        case .announcements:
            return LocalizedString("forums-list.announcements-section-title")
        case .favorites:
            return LocalizedString("forums-list.favorite-forums.section-title")
        case .forumGroup(let name):
            return String(name.dropFirst(ForumGroup.sectionIdentifierIndexLength + 1))
        }
    }

    var hasFavorites: Bool {
        return (favoriteForumsController.fetchedObjects?.count ?? 0) > 0
    }

    var nextFavoriteIndex: Int32 {
        let last = favoriteForumsController.fetchedObjects?.last
        return last.map { $0.favoriteIndex + 1 } ?? 1
    }

    func canEditItem(at indexPath: IndexPath) -> Bool {
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return false }
        if case .favoriteForum = item { return true }
        return false
    }

    func deleteFavorite(at indexPath: IndexPath) {
        guard case .favoriteForum(let id) = diffableDataSource.itemIdentifier(for: indexPath),
              let metadata = forumsController.managedObjectContext.object(with: id) as? ForumMetadata
        else { return }
        updateMetadata(metadata, setIsFavorite: false)
    }

    /// Constrain a proposed move target index path so that favorites can only
    /// be reordered within the favorites section.
    func proposedTargetIndexPath(for sourceIndexPath: IndexPath, proposed proposedDestination: IndexPath) -> IndexPath {
        let snapshot = diffableDataSource.snapshot()
        let sectionIds = snapshot.sectionIdentifiers

        guard sourceIndexPath.section < sectionIds.count,
              case .favorites = sectionIds[sourceIndexPath.section]
        else {
            return sourceIndexPath
        }

        if proposedDestination.section < sectionIds.count,
           case .favorites = sectionIds[proposedDestination.section] {
            return proposedDestination
        }

        guard let favoritesIndex = sectionIds.firstIndex(of: .favorites) else {
            return sourceIndexPath
        }

        let favoritesItemCount = snapshot.numberOfItems(inSection: .favorites)

        if proposedDestination.section > favoritesIndex {
            return IndexPath(item: max(0, favoritesItemCount - 1), section: favoritesIndex)
        } else {
            return IndexPath(item: 0, section: favoritesIndex)
        }
    }

    private func applyReorderTransaction(_ transaction: NSDiffableDataSourceTransaction<Section, Item>) {
        let context = forumsController.managedObjectContext
        let favoritesItems = transaction.finalSnapshot.itemIdentifiers(inSection: .favorites)

        let metadatas: [ForumMetadata] = favoritesItems.compactMap { item in
            if case .favoriteForum(let id) = item {
                return context.object(with: id) as? ForumMetadata
            }
            return nil
        }

        ignoreControllerUpdates = true
        zip(metadatas, 1...).forEach { $0.favoriteIndex = Int32($1) }
        try! metadatas.first?.managedObjectContext?.save()
        ignoreControllerUpdates = false
    }

    private func updateMetadata(_ metadata: ForumMetadata, setIsFavorite isFavorite: Bool) {
        logger.debug("\(isFavorite ? "adding" : "removing") favorite forum \(metadata.forum.name ?? "")")

        metadata.favorite = isFavorite
        metadata.forum.tickleForFetchedResultsController()
        try! metadata.managedObjectContext?.save()

        undoManager.registerUndo(withTarget: self) { dataSource in
            dataSource.updateMetadata(metadata, setIsFavorite: !isFavorite)
        }
        undoManager.setActionName(
            LocalizedString(isFavorite
                ? "forums-list.undo-action.add-favorite"
                : "forums-list.undo-action.remove-favorite"))
    }

    func viewModelFor(item: Item) -> ForumListCell.ViewModel {
        let theme = delegate?.themeForCells(in: self) ?? Theme.defaultTheme()

        switch item {
        case .announcement:
            let announcement = objectFor(item: item) as! Announcement
            return ForumListCell.ViewModel(
                backgroundColor: theme["listBackgroundColor"]!,
                expansion: .none,
                expansionTintColor: theme["expansionTintColor"]!,
                favoriteStar: announcement.hasBeenSeen ? .hidden : .isFavorite,
                favoriteStarTintColor: theme["favoriteStarTintColor"]!,
                forumName: NSAttributedString(string: announcement.title, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], weight: .regular),
                    .foregroundColor: theme[uicolor: "listTextColor"]!]),
                indentationLevel: 0,
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)

        case .favoriteForum:
            let forum = objectFor(item: item) as! Forum
            return ForumListCell.ViewModel(
                backgroundColor: theme["listBackgroundColor"]!,
                expansion: .none,
                expansionTintColor: theme["expansionTintColor"]!,
                favoriteStar: .isFavorite,
                favoriteStarTintColor: theme["favoriteStarTintColor"]!,
                forumName: NSAttributedString(string: forum.name ?? "", attributes: [
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], weight: .regular),
                    .foregroundColor: theme[uicolor: "listTextColor"]!]),
                indentationLevel: 0,
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)

        case .forum:
            let forum = objectFor(item: item) as! Forum
            return ForumListCell.ViewModel(
                backgroundColor: theme["listBackgroundColor"]!,
                expansion: {
                    if forum.childForums.isEmpty {
                        return .none
                    } else if forum.metadata.showsChildrenInForumList {
                        return .isExpanded
                    } else {
                        return .canExpand
                    }
                }(),
                expansionTintColor: theme["expansionTintColor"]!,
                favoriteStar: forum.metadata.favorite ? .hidden : .canFavorite,
                favoriteStarTintColor: theme["favoriteStarTintColor"]!,
                forumName: NSAttributedString(string: forum.name ?? "", attributes: [
                    .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], weight: .regular),
                    .foregroundColor: theme[uicolor: "listTextColor"]!]),
                indentationLevel: forum.ancestors.reduce(0) { i, _ in i + 1 },
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)
        }
    }
}

extension ForumListDataSource: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard !ignoreControllerUpdates else { return }
        scheduleSnapshotApply()
    }
}

protocol ForumListDataSourceDelegate: AnyObject {
    func themeForCells(in dataSource: ForumListDataSource) -> Theme
}
