//  ThreadListDataSource.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulTheming
import CoreData
import os
import UIKit

enum BookmarkFilter {
    case all
    case unreadOnly
    case readOnly
    case starCategory(StarCategory)
    case textSearch(String)
}

extension BookmarkFilter {
    /// Returns nil for `.textSearch` so transient queries are not persisted.
    var persistenceKey: String? {
        switch self {
        case .all: return "all"
        case .unreadOnly: return "unread"
        case .readOnly: return "read"
        case .starCategory(let c): return "star_\(c.rawValue)"
        case .textSearch: return nil
        }
    }

    init(persistenceKey: String) {
        switch persistenceKey {
        case "unread": self = .unreadOnly
        case "read": self = .readOnly
        case let s where s.hasPrefix("star_"):
            if let raw = Int16(s.dropFirst("star_".count)),
               let cat = StarCategory(rawValue: raw) {
                self = .starCategory(cat)
            } else {
                self = .all
            }
        default: self = .all
        }
    }
}

private let Log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadListDataSource")

final class ThreadListDataSource: NSObject {
    weak var delegate: ThreadListDataSourceDelegate?
    weak var deletionDelegate: ThreadListDataSourceDeletionDelegate?
    private let ignoreSticky: Bool
    private let placeholder: ThreadTagLoader.Placeholder
    private let resultsController: NSFetchedResultsController<AwfulThread>
    private let showsTagAndRating: Bool
    private let collectionView: UICollectionView
    private var diffableDataSource: UICollectionViewDiffableDataSource<Int, NSManagedObjectID>!

    convenience init(
        bookmarksSortedByUnread sortedByUnread: Bool,
        showsTagAndRating: Bool,
        filter: BookmarkFilter,
        managedObjectContext: NSManagedObjectContext,
        collectionView: UICollectionView,
        supplementaryViewProvider: @escaping (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    ) throws {
        let fetchRequest = AwfulThread.makeFetchRequest()
        fetchRequest.predicate = ThreadListDataSource.bookmarksPredicate(for: filter)
        fetchRequest.sortDescriptors = {
            var descriptors = [NSSortDescriptor(key: #keyPath(AwfulThread.bookmarkListPage), ascending: true)]
            if sortedByUnread {
                descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.anyUnreadPosts), ascending: false))
            }
            descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.lastPostDate), ascending: false))
            return descriptors
        }()

        try self.init(
            managedObjectContext: managedObjectContext,
            fetchRequest: fetchRequest,
            collectionView: collectionView,
            supplementaryViewProvider: supplementaryViewProvider,
            ignoreSticky: true,
            showsTagAndRating: showsTagAndRating,
            placeholder: .thread(tintColor: nil)
        )
    }

    private static func bookmarksPredicate(for filter: BookmarkFilter) -> NSPredicate {
        var predicates = [
            NSPredicate(format: "%K == YES && %K > 0", #keyPath(AwfulThread.bookmarked), #keyPath(AwfulThread.bookmarkListPage))
        ]

        switch filter {
        case .all:
            break
        case .unreadOnly:
            predicates.append(NSPredicate(format: "%K == YES", #keyPath(AwfulThread.anyUnreadPosts)))
        case .readOnly:
            predicates.append(NSPredicate(format: "%K == NO", #keyPath(AwfulThread.anyUnreadPosts)))
        case .starCategory(let category):
            predicates.append(NSPredicate(format: "%K == %d", "starCategory", category.rawValue))
        case .textSearch(let searchText):
            let titlePredicate = NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(AwfulThread.title), searchText)
            let authorPredicate = NSPredicate(format: "%K.%K CONTAINS[cd] %@", #keyPath(AwfulThread.author), #keyPath(User.username), searchText)
            let textPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, authorPredicate])
            predicates.append(textPredicate)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Update the bookmark fetch predicate in place. Prefer this over recreating
    /// the data source on filter changes — recreating rebinds the collection
    /// view's data source, which causes supplementary views (the search bar) to
    /// lose their first-responder status between keystrokes.
    ///
    /// `animated: false` is the right call when the filter is being driven by
    /// a search field that's currently the first responder — the snapshot apply
    /// animation briefly dehosts the supplementary view, dropping focus and
    /// any in-flight text input.
    func setBookmarkFilter(_ filter: BookmarkFilter, animated: Bool = true) {
        resultsController.fetchRequest.predicate = ThreadListDataSource.bookmarksPredicate(for: filter)
        do {
            try resultsController.performFetch()
            applyCurrentSnapshot(animatingDifferences: animated)
        } catch {
            Log.error("Failed to re-fetch with new bookmark filter: \(error)")
        }
    }

    convenience init(
        forum: Forum,
        sortedByUnread: Bool,
        showsTagAndRating: Bool,
        threadTagFilter: Set<ThreadTag>,
        managedObjectContext: NSManagedObjectContext,
        collectionView: UICollectionView,
        supplementaryViewProvider: @escaping (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    ) throws {
        let fetchRequest = AwfulThread.makeFetchRequest()

        fetchRequest.predicate = {
            var predicates = [NSPredicate(format: "%K > 0 && %K == %@", #keyPath(AwfulThread.threadListPage), #keyPath(AwfulThread.forum), forum)]
            if !threadTagFilter.isEmpty {
                predicates.append(NSPredicate(format: "%K IN %@", #keyPath(AwfulThread.threadTag), threadTagFilter))
            }
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }()

        fetchRequest.sortDescriptors = {
            var descriptors = [
                NSSortDescriptor(key: #keyPath(AwfulThread.stickyIndex), ascending: true),
                NSSortDescriptor(key: #keyPath(AwfulThread.threadListPage), ascending: true)]
            if sortedByUnread {
                descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.anyUnreadPosts), ascending: false))
            }
            descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.lastPostDate), ascending: false))
            return descriptors
        }()

        try self.init(
            managedObjectContext: managedObjectContext,
            fetchRequest: fetchRequest,
            collectionView: collectionView,
            supplementaryViewProvider: supplementaryViewProvider,
            ignoreSticky: false,
            showsTagAndRating: showsTagAndRating,
            placeholder: .thread(in: forum)
        )
    }

    private init(
        managedObjectContext: NSManagedObjectContext,
        fetchRequest: NSFetchRequest<AwfulThread>,
        collectionView: UICollectionView,
        supplementaryViewProvider: @escaping (UICollectionView, String, IndexPath) -> UICollectionReusableView?,
        ignoreSticky: Bool,
        showsTagAndRating: Bool,
        placeholder: ThreadTagLoader.Placeholder
    ) throws {
        self.ignoreSticky = ignoreSticky
        self.placeholder = placeholder
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        self.showsTagAndRating = showsTagAndRating
        self.collectionView = collectionView
        super.init()

        // Cell registration is owned by the data source so it captures `self`
        // (this data source). If the VC owned the registration and captured
        // its own `dataSource` property, then during a filter change the new
        // data source's initial snapshot apply would resolve the registration
        // closure against the OLD data source (which still has more rows),
        // crashing on index-out-of-bounds.
        let cellRegistration = UICollectionView.CellRegistration<ThreadListCell, NSManagedObjectID> { [weak self] cell, indexPath, _ in
            guard let self else { return }
            cell.viewModel = self.viewModelFor(threadAt: indexPath)
            cell.accessories = [
                .delete(displayed: .whenEditing, actionHandler: { [weak self] in
                    guard let self else { return }
                    let thread = self.thread(at: indexPath)
                    self.deletionDelegate?.didDeleteThread(thread, in: self)
                }),
            ]
        }

        diffableDataSource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>(collectionView: collectionView) { collectionView, indexPath, objectID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: objectID)
        }
        diffableDataSource.supplementaryViewProvider = supplementaryViewProvider

        resultsController.delegate = self
        try resultsController.performFetch()
        applyCurrentSnapshot(animatingDifferences: false)

        NotificationCenter.default.addObserver(self, selector: #selector(dataStoreDidReset), name: .dataStoreDidReset, object: nil)
    }

    @objc private func dataStoreDidReset() {
        // The old store's objects are no longer reachable from the coordinator. Re-fetch
        // against the fresh store so the FRC's cache stops pointing at dangling objectIDs.
        do {
            try resultsController.performFetch()
        } catch {
            Log.error("Failed to re-fetch after data store reset: \(error)")
        }
        applyCurrentSnapshot(animatingDifferences: false)
    }

    private func applyCurrentSnapshot(animatingDifferences: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>()
        snapshot.appendSections([0])
        let objectIDs = (resultsController.fetchedObjects ?? []).map(\.objectID)
        snapshot.appendItems(objectIDs, toSection: 0)
        diffableDataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    func indexPath(of thread: AwfulThread) -> IndexPath? {
        return resultsController.indexPath(forObject: thread)
    }

    func thread(at indexPath: IndexPath) -> AwfulThread {
        return resultsController.object(at: indexPath)
    }

    func numberOfThreads(in section: Int) -> Int {
        return resultsController.sections?.first?.numberOfObjects ?? 0
    }

    func viewModelFor(threadAt indexPath: IndexPath) -> ThreadListCell.ViewModel {
        let thread = resultsController.object(at: indexPath)
        let theme = delegate?.themeForItem(at: indexPath, in: self) ?? .defaultTheme()
        let tweaks = thread.forum.flatMap { ForumTweaks(ForumID($0.forumID)) }

        return ThreadListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            pageCount: NSAttributedString(string: "\(thread.numberOfPages)", attributes: [
                .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .semibold),
                .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!]),
            pageIconColor: theme["threadListPageIconColor"]!,
            postInfo: {
                let text: String
                if thread.beenSeen {
                    text = String(format: LocalizedString("thread-list.killed-by"), thread.lastPostAuthorName ?? "")
                }
                else {
                    text = String(format: LocalizedString("thread-list.posted-by"), thread.author?.username ?? "")
                }
                return NSAttributedString(string: text, attributes: [
                    .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .semibold),
                    .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!])
            }(),
            ratingImage: {
                if !showsTagAndRating {
                    return nil
                }

                if let tweaks = tweaks, tweaks.showRatingsAsThreadTags {
                    return nil
                }

                return thread.ratingImageName.flatMap {
                    if $0 != "Vote0" {
                        return UIImage(named: "Vote0")!
                            .withTintColor(Theme.defaultTheme()["ratingIconEmptyColor"]!)
                            .mergeWith(topImage: UIImage(named: $0)!)
                    }
                    return UIImage(named: "Vote0")!
                        .withTintColor(Theme.defaultTheme()["ratingIconEmptyColor"]!)
                }
            }(),
            secondaryTagImageName: {
                if !showsTagAndRating {
                    return nil
                }
                return thread.secondaryThreadTag?.imageName
            }(),
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!,
            stickyImage: !ignoreSticky && thread.sticky ? UIImage(named: "sticky") : nil,
            tagImage: {
                if !showsTagAndRating {
                    return .none
                }

                if let tweaks = tweaks, tweaks.showRatingsAsThreadTags, let imageName = thread.ratingTagImageName {
                    return .image(name: imageName, placeholder: placeholder)
                } else {
                    return .image(name: thread.threadTag?.imageName, placeholder: placeholder)
                }
            }(),
            title: NSAttributedString(string: thread.title ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .regular),
                .foregroundColor: theme[uicolor: thread.closed ? "listSecondaryTextColor" : "listTextColor"]!]),
            unreadCount: {
                guard thread.beenSeen else { return NSAttributedString() }
                let color: UIColor
                if thread.unreadPosts == 0 {
                    color = theme["unreadBadgeGrayColor"]!
                } else {
                    switch thread.starCategory {
                    case .orange: color = theme["unreadBadgeOrangeColor"]!
                    case .red: color = theme["unreadBadgeRedColor"]!
                    case .yellow: color = theme["unreadBadgeYellowColor"]!
                    case .cyan: color = theme["unreadBadgeCyanColor"]!
                    case .green: color = theme["unreadBadgeGreenColor"]!
                    case .purple: color = theme["unreadBadgePurpleColor"]!
                    case .none: color = theme["unreadBadgeBlueColor"]!
                    }
                }
                return NSAttributedString(string: "\(thread.unreadPosts)", attributes: [
                    .font: UIFont.preferredFontForTextStyle(.caption1, fontName: theme["listFontName"], sizeAdjustment: 1, weight: .semibold), .foregroundColor: color])
        }())
    }
}

extension ThreadListDataSource: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        let typedSnapshot = snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        diffableDataSource.apply(typedSnapshot, animatingDifferences: true)
    }
}

protocol ThreadListDataSourceDelegate: AnyObject {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme
}

protocol ThreadListDataSourceDeletionDelegate: AnyObject {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource)
}
