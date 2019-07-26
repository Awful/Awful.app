//  PrimarySidebarViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

/// A primary sidebar view controller lists the main areas of the app (e.g. Forums, Bookmarks, Messages, Lepers) as well as favorite forums. It's intended for use within a `ThreePaneViewController`.
@available(iOS 13.0, *)
final class PrimarySidebarViewController: UIViewController {

    weak var delegate: PrimarySidebarViewControllerDelegate?

    var selectedItem: Item = .allForums {
        didSet { update() }
    }

    enum Section: Int, CaseIterable, Hashable {
        case forums
        case other
    }

    enum Item: Hashable {
        case allForums
        case bookmarkedThreads
        case favoriteForum(forumID: String, name: String)
        case lepersColony
        case privateMessages
    }

    private var dataSource: UITableViewDiffableDataSource<Section, Item>?
    private let favoriteForumsController: NSFetchedResultsController<ForumMetadata>

    init(managedObjectContext: NSManagedObjectContext) {
        let favoriteForumsRequest = NSFetchRequest<ForumMetadata>(entityName: ForumMetadata.entityName())
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        favoriteForumsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init(nibName: nil, bundle: nil)

        try! favoriteForumsController.performFetch()
        favoriteForumsController.delegate = self

        preferredContentSize = CGSize(width: 175, height: 200)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.estimatedRowHeight = PrimarySidebarCell.estimatedRowHeight
        tableView.register(UINib(nibName: "PrimarySidebarCell", bundle: Bundle(for: PrimarySidebarCell.self)), forCellReuseIdentifier: "PrimarySidebarCell")
        tableView.tableFooterView = UIView()
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = .init(tableView: tableView, cellProvider: { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "PrimarySidebarCell") as! PrimarySidebarCell
            switch item {
            case .allForums:
                cell.configure(title: NSLocalizedString("forums-list.title", comment: ""))

            case .bookmarkedThreads:
                cell.configure(title: NSLocalizedString("bookmarks.title", comment: ""))

            case .favoriteForum(_, let name):
                cell.configure(title: name)

            case .lepersColony:
                cell.configure(title: NSLocalizedString("lepers-colony.tabbar-title", comment: ""))

            case .privateMessages:
                cell.configure(title: NSLocalizedString("private-message-tab.title", comment: ""))
            }
            return cell
        })

        view.addSubview(tableView, constrainEdges: .all)

        update()
    }

    private func update() {
        let snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([.allForums], toSection: .forums)
        snapshot.appendItems(favoriteForumsController.fetchedObjects?
            .map { .favoriteForum(forumID: $0.forum.forumID, name: $0.forum.name ?? "") }
            ?? [])

        snapshot.appendItems([.bookmarkedThreads, .lepersColony], toSection: .other)
        if UserDefaults.standard.loggedInUserCanSendPrivateMessages {
            snapshot.insertItems([.privateMessages], afterItem: .bookmarkedThreads)
        }

        dataSource?.apply(snapshot)
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Delegate

@available(iOS 13.0, *)
protocol PrimarySidebarViewControllerDelegate: AnyObject {
    func didSelect(_ item: PrimarySidebarViewController.Item, in viewController: PrimarySidebarViewController)
}

// MARK: - Fetched results controller

@available(iOS 13.0, *)
extension PrimarySidebarViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        update()
    }
}

// MARK: - Table View

@available(iOS 13.0, *)
extension PrimarySidebarViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedItem = dataSource?.itemIdentifier(for: indexPath) {
            self.selectedItem = selectedItem
            delegate?.didSelect(selectedItem, in: self)
        }
    }
}
