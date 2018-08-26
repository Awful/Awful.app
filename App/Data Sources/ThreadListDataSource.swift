//  ThreadListDataSource.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get()

final class ThreadListDataSource: NSObject {
    weak var delegate: ThreadListDataSourceDelegate?
    weak var deletionDelegate: ThreadListDataSourceDeletionDelegate?
    private let ignoreSticky: Bool
    private let resultsController: NSFetchedResultsController<AwfulThread>
    private let showsTagAndRating: Bool
    private let tableView: UITableView

    convenience init(bookmarksSortedByUnread sortedByUnread: Bool, showsTagAndRating: Bool, managedObjectContext: NSManagedObjectContext, tableView: UITableView) throws {
        let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())

        fetchRequest.predicate = NSPredicate(format: "%K == YES && %K > 0", #keyPath(AwfulThread.bookmarked), #keyPath(AwfulThread.bookmarkListPage))

        fetchRequest.sortDescriptors = {
            var descriptors = [NSSortDescriptor(key: #keyPath(AwfulThread.bookmarkListPage), ascending: true)]
            if sortedByUnread {
                descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.anyUnreadPosts), ascending: false))
            }
            descriptors.append(NSSortDescriptor(key: #keyPath(AwfulThread.lastPostDate), ascending: false))
            return descriptors
        }()

        try self.init(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest, tableView: tableView, ignoreSticky: true, showsTagAndRating: showsTagAndRating)
    }

    convenience init(forum: Forum, sortedByUnread: Bool, showsTagAndRating: Bool, threadTagFilter: Set<ThreadTag>, managedObjectContext: NSManagedObjectContext, tableView: UITableView) throws {
        let fetchRequest = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName())

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

        try self.init(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest, tableView: tableView, ignoreSticky: false, showsTagAndRating: showsTagAndRating)
    }

    private init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest<AwfulThread>, tableView: UITableView, ignoreSticky: Bool, showsTagAndRating: Bool) throws {
        self.ignoreSticky = ignoreSticky
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        self.showsTagAndRating = showsTagAndRating
        self.tableView = tableView
        super.init()

        try resultsController.performFetch()

        tableView.dataSource = self
        tableView.register(ThreadListCell.self, forCellReuseIdentifier: threadCellIdentifier)

        resultsController.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(threadTagLoaderNewImageAvailable), name: ThreadTagLoader.NewImageAvailableNotification.name, object: ThreadTagLoader.sharedLoader)
    }

    func indexPath(of thread: AwfulThread) -> IndexPath? {
        return resultsController.indexPath(forObject: thread)
    }

    func thread(at indexPath: IndexPath) -> AwfulThread {
        return resultsController.object(at: indexPath)
    }

    @objc private func threadTagLoaderNewImageAvailable(_ notification: Notification) {
        let notification = ThreadTagLoader.NewImageAvailableNotification(notification)
        let reloads = (tableView.indexPathsForVisibleRows ?? [])
            .filter {
                let thread = resultsController.object(at: $0)
                return thread.threadTag?.imageName == notification.newImageName
                    || thread.secondaryThreadTag?.imageName == notification.newImageName
        }

        Log.d("loaded thread tag \(notification.newImageName), will reload \(reloads.count) row\(reloads.count == 1 ? "" : "s")")

        if !reloads.isEmpty {
            tableView.beginUpdates()
            tableView.reloadRows(at: reloads, with: .none)
            tableView.endUpdates()
        }
    }
}

extension ThreadListDataSource: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move, .update:
            assertionFailure("why")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at oldIndexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            tableView.deleteRows(at: [oldIndexPath!], with: .fade)
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .move:
            tableView.deleteRows(at: [oldIndexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [oldIndexPath!], with: .none)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

extension ThreadListDataSource: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections?.first?.numberOfObjects ?? 0
    }

    // This is actually a UITableViewDelegate method.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let viewModel = viewModelForCell(at: indexPath)
        return ThreadListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.bounds.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: threadCellIdentifier, for: indexPath) as! ThreadListCell
        cell.viewModel = viewModelForCell(at: indexPath)
        return cell
    }

    private func viewModelForCell(at indexPath: IndexPath) -> ThreadListCell.ViewModel {
        let thread = resultsController.object(at: indexPath)
        let theme = delegate?.themeForItem(at: indexPath, in: self) ?? .currentTheme
        let tweaks = thread.forum.flatMap { ForumTweaks(forumID: $0.forumID) }

        return ThreadListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            pageCount: NSAttributedString(string: "\(thread.numberOfPages)", attributes: [
                .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"]),
                .foregroundColor: (theme["listSecondaryTextColor"] as UIColor?)!]),
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
                    .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"]),
                    .foregroundColor: (theme["listSecondaryTextColor"] as UIColor?)!])
            }(),
            ratingImage: {
                if !showsTagAndRating {
                    return nil
                }

                if let tweaks = tweaks, tweaks.showRatingsAsThreadTags {
                    return nil
                }

                return thread.ratingImageName.flatMap { UIImage(named: $0) }
            }(),
            secondaryTagImage: {
                if !showsTagAndRating {
                    return nil
                }

                let imageName = thread.secondaryThreadTag?.imageName
                guard imageName != thread.threadTag?.imageName else {
                    return nil
                }

                return imageName.flatMap { ThreadTagLoader.sharedLoader.imageNamed($0) }
            }(),
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!,
            stickyImage: !ignoreSticky && thread.sticky ? UIImage(named: "sticky") : nil,
            tagImage: {
                if !showsTagAndRating {
                    return nil
                }

                let imageName: String?
                if let tweaks = tweaks, tweaks.showRatingsAsThreadTags {
                    imageName = thread.ratingTagImageName
                }
                else {
                    imageName = thread.threadTag?.imageName
                }

                return imageName.flatMap { ThreadTagLoader.sharedLoader.imageNamed($0) }
                    ?? ThreadTagLoader.emptyThreadTagImage.withTint(theme["listTextColor"]!)
            }(),
            title: NSAttributedString(string: thread.title ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"]),
                .foregroundColor: (theme[thread.closed ? "listSecondaryTextColor" : "listTextColor"] as UIColor?)!]),
            unreadCount: {
                guard thread.beenSeen else { return NSAttributedString() }
                let color: UIColor
                if thread.unreadPosts == 0 {
                    color = theme["unreadBadgeGrayColor"]!
                } else {
                    switch thread.starCategory {
                    case .Orange: color = theme["unreadBadgeOrangeColor"]!
                    case .Red: color = theme["unreadBadgeRedColor"]!
                    case .Yellow: color = theme["unreadBadgeYellowColor"]!
                    case .None: color = theme["unreadBadgeBlueColor"]!
                    }
                }
                return NSAttributedString(string: "\(thread.unreadPosts)", attributes: [
                    .font: UIFont.preferredFontForTextStyle(.caption1, fontName: theme["listFontName"], sizeAdjustment: 2),
                    .foregroundColor: color])
        }())
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return deletionDelegate != nil
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let thread = self.thread(at: indexPath)
        deletionDelegate?.didDeleteThread(thread, in: self)
    }
}

private let threadCellIdentifier = "ThreadListCell"

protocol ThreadListDataSourceDelegate: class {
    func themeForItem(at indexPath: IndexPath, in dataSource: ThreadListDataSource) -> Theme
}

protocol ThreadListDataSourceDeletionDelegate: class {
    func didDeleteThread(_ thread: AwfulThread, in dataSource: ThreadListDataSource)
}
