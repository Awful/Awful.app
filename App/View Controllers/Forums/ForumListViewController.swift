//  ForumListViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

@available(iOS 13.0, *)
final class ForumListViewController: UIViewController {

    private let resultsController: NSFetchedResultsController<Forum>

    init(managedObjectContext: NSManagedObjectContext) {
        let request = NSFetchRequest<Forum>(entityName: Forum.entityName())
        request.fetchBatchSize = 50 // Approximately two screenfuls on an iPad in portrait.
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "%K == YES", #keyPath(Forum.metadata.visibleInForumList))
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true), // section
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]

        resultsController = .init(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: #keyPath(Forum.group.sectionIdentifier),
            cacheName: nil)

        super.init(nibName: nil, bundle: nil)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ForumListSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: "Header")
        tableView.register(ForumListCell.self, forCellReuseIdentifier: "Forum")
        return tableView
    }()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView, constrainEdges: .all)

        try! resultsController.performFetch()
        resultsController.delegate = self

        themeDidChange()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        for indexPath in tableView.indexPathsForSelectedRows ?? [] {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableView.flashScrollIndicators()
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Navigation

extension ForumListViewController {
    func openForum(_ forum: Forum, animated: Bool) {
        let threadList = ThreadsTableViewController(forum: forum)
        threadList.restorationClass = ThreadsTableViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }
}

// MARK: Helpers

extension ForumListViewController {
    private func makeViewModel(for forum: Forum) -> ForumListCell.ViewModel {
        return .init(
            backgroundColor: theme["listBackgroundColor"]!,
            expansion: {
                if forum.childForums.isEmpty {
                    return .none
                }
                else if forum.metadata.showsChildrenInForumList {
                    return .isExpanded
                }
                else {
                    return .canExpand
                }
            }(),
            expansionTintColor: theme["tintColor"]!,
            favoriteStar: forum.metadata.favorite ? .hidden : .canFavorite,
            favoriteStarTintColor: theme["tintColor"]!,
            forumName: NSAttributedString(string: forum.name ?? "", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: theme[color: "listTextColor"]!]),
            indentationLevel: forum.ancestors.reduce(0) { i, _ in i + 1 },
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)
    }
}

extension ForumListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for change: NSFetchedResultsChangeType)
    {
        switch change {
        case .insert:
            tableView.insertSections([sectionIndex], with: .fade)

        case .delete:
            tableView.deleteSections([sectionIndex], with: .fade)

        case .move, .update:
            assertionFailure("docs say this shouldn't happen")

        @unknown default:
            assertionFailure("handle unknown change type")
        }
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at oldIndexPath: IndexPath?,
        for change: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?)
    {
        switch change {
        case .insert:
            guard let indexPath = newIndexPath else { fatalError("need inserted index path") }
            tableView.insertRows(at: [indexPath], with: .fade)

        case .delete:
            guard let indexPath = oldIndexPath else { fatalError("need deleted index path") }
            tableView.deleteRows(at: [indexPath], with: .fade)

        case .update:
            guard let indexPath = oldIndexPath else { fatalError("need updated index path") }
            let forum = resultsController.object(at: indexPath)
            guard let cell = tableView.cellForRow(at: indexPath) as! ForumListCell? else { break }
            cell.viewModel = makeViewModel(for: forum)

        case .move:
            guard let from = oldIndexPath else { fatalError("need 'move from' index path") }
            guard let to = newIndexPath else { fatalError("need 'move to' index path") }
            tableView.moveRow(at: from, to: to)

        @unknown default:
            assertionFailure("handle unknown change type")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

extension ForumListViewController: Themeable {
    var theme: Theme { Theme.defaultTheme() }

    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]

        tableView.backgroundColor = theme["backgroundColor"]
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]

        tableView.reloadData()
    }
}

extension ForumListViewController: UITableViewDataSource & UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = resultsController.sections?[section] else { return nil }
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "Header") as! ForumListSectionHeaderView

        let readableName = section.name.dropFirst(ForumGroup.sectionIdentifierIndexLength + 1)
        headerView.viewModel = .init(
            backgroundColor: theme["listHeaderBackgroundColor"],
            font: UIFont.preferredFont(forTextStyle: .body),
            sectionName: String(readableName),
            textColor: theme["listHeaderTextColor"])
        return headerView
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections?[section].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let forum = resultsController.object(at: indexPath)
        let viewModel = makeViewModel(for: forum)
        return ForumListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.safeAreaFrame.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Forum", for: indexPath) as! ForumListCell
        let forum = resultsController.object(at: indexPath)
        cell.viewModel = makeViewModel(for: forum)

        cell.didTapExpand = { cell in
            forum.toggleCollapseExpand()
            try! forum.managedObjectContext?.save()
        }

        cell.didTapFavorite = { cell in
            forum.toggleFavorite()
            try! forum.managedObjectContext?.save()
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let forum = resultsController.object(at: indexPath)
        openForum(forum, animated: true)
    }
}
