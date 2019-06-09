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
    private let placeholder: ThreadTagLoader.Placeholder
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

        try self.init(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest, tableView: tableView, ignoreSticky: true, showsTagAndRating: showsTagAndRating, placeholder: .thread(tintColor: nil))
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

        try self.init(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest, tableView: tableView, ignoreSticky: false, showsTagAndRating: showsTagAndRating, placeholder: .thread(in: forum))
    }

    private init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest<AwfulThread>, tableView: UITableView, ignoreSticky: Bool, showsTagAndRating: Bool, placeholder: ThreadTagLoader.Placeholder) throws {
        self.ignoreSticky = ignoreSticky
        self.placeholder = placeholder
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        self.showsTagAndRating = showsTagAndRating
        self.tableView = tableView
        super.init()

        try resultsController.performFetch()

        tableView.dataSource = self
        tableView.register(ThreadListCell.self, forCellReuseIdentifier: threadCellIdentifier)

        resultsController.delegate = self
    }

    func indexPath(of thread: AwfulThread) -> IndexPath? {
        return resultsController.indexPath(forObject: thread)
    }

    func thread(at indexPath: IndexPath) -> AwfulThread {
        return resultsController.object(at: indexPath)
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
        @unknown default:
            assertionFailure("handle unknown change type")
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
        @unknown default:
            assertionFailure("handle unknown change type")
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
        return ThreadListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.safeAreaFrame.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: threadCellIdentifier, for: indexPath) as! ThreadListCell
        cell.viewModel = viewModelForCell(at: indexPath)
        return cell
    }

    private func viewModelForCell(at indexPath: IndexPath) -> ThreadListCell.ViewModel {
        let thread = resultsController.object(at: indexPath)
        let theme = delegate?.themeForItem(at: indexPath, in: self) ?? .defaultTheme()
        let tweaks = thread.forum.flatMap { ForumTweaks(forumID: $0.forumID) }

        return ThreadListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            pageCount: NSAttributedString(string: "\(thread.numberOfPages)", attributes: [
                .font: UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"]),
                .foregroundColor: theme[color: "listSecondaryTextColor"]!]),
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
                    .foregroundColor: theme[color: "listSecondaryTextColor"]!])
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
                .font: UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"]),
                .foregroundColor: theme[color: thread.closed ? "listSecondaryTextColor" : "listTextColor"]!]),
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

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
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
