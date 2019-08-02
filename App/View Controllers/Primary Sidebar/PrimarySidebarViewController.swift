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
        case topItems
        case favoriteForums
    }

    enum Item: Hashable {
        case allForums
        case announcements
        case bookmarkedThreads
        case favoriteForum(name: String, objectID: NSManagedObjectID)
        case lepersColony
        case privateMessages
    }

    private var announcementsCountObserver: ManagedObjectCountObserver?
    private var dataSource: UITableViewDiffableDataSource<Section, Item>?
    private let resultsController: NSFetchedResultsController<ForumMetadata>

    init(managedObjectContext: NSManagedObjectContext) {
        let favoriteForumsRequest = NSFetchRequest<ForumMetadata>(entityName: ForumMetadata.entityName())
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        resultsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 175, height: 200)

        announcementsCountObserver = .init(
            context: managedObjectContext,
            entityName: Announcement.entityName(),
            predicate: NSPredicate(value: true),
            didChange: { [weak self] count in self?.update() })
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

        dataSource = .init(tableView: tableView, cellProvider: {
            [unowned self] tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "PrimarySidebarCell") as! PrimarySidebarCell
            cell.backgroundColor = self.theme["backgroundColor"]

            switch item {
            case .allForums:
                cell.configure(
                    icon: UIImage(named: "forum-list"),
                    title: NSLocalizedString("forums-list.title", comment: ""))

            case .announcements:
                cell.configure(
                    icon: UIImage(named: "forum-list"),
                    title: NSLocalizedString("announcements-list.title", comment: ""))

            case .bookmarkedThreads:
                cell.configure(
                    icon: UIImage(named: "bookmarks"),
                    title: NSLocalizedString("bookmarks.title", comment: ""))

            case .favoriteForum(name: let name, objectID: _):
                cell.configure(
                    icon: UIImage(named: "star-on"),
                    title: name)

            case .lepersColony:
                cell.configure(
                    icon: UIImage(named: "lepers"),
                    title: NSLocalizedString("lepers-colony.tabbar-title", comment: ""))

            case .privateMessages:
                cell.configure(
                    icon: UIImage(named: "pm-icon"),
                    title: NSLocalizedString("private-message-tab.title", comment: ""))
            }
            return cell
        })

        view.addSubview(tableView, constrainEdges: .all)

        themeDidChange()

        try! resultsController.performFetch()
        update()

        resultsController.delegate = self
    }

    private func update() {
        let snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([.allForums, .bookmarkedThreads, .lepersColony], toSection: .topItems)

        if let announcementCount = announcementsCountObserver?.count, announcementCount > 0 {
            snapshot.insertItems([.announcements], beforeItem: .allForums)
        }

        if UserDefaults.standard.loggedInUserCanSendPrivateMessages {
            snapshot.insertItems([.privateMessages], afterItem: .bookmarkedThreads)
        }

        snapshot.appendItems(
            resultsController.fetchedObjects?
                .map { .favoriteForum(name: $0.forum.name ?? "", objectID: $0.forum.objectID) }
                ?? [],
            toSection: .favoriteForums)

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

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        switch dataSource?.itemIdentifier(for: indexPath) {
        case let .favoriteForum(name: _, objectID: objectID):
            let delete = { [unowned self] in
                let context = self.resultsController.managedObjectContext
                let forum = context.object(with: objectID) as! Forum
                forum.removeFavorite()
                try! context.save()
            }
            let menu = UIMenu(title: "", image: nil, identifier: nil, children: [
                UIAction(
                    title: NSLocalizedString("forums-list.context-menu.delete-favorite", comment: ""),
                    handler: { action in delete() })])
            return UIContextMenuConfiguration(
                identifier: objectID,
                previewProvider: nil,
                actionProvider: { suggestedItems in menu })

        case .allForums, .announcements, .bookmarkedThreads, .lepersColony, .privateMessages, nil:
            return nil
        }
    }
}

// MARK: - Theme

@available(iOS 13.0, *)
extension PrimarySidebarViewController: Themeable {
    var theme: Theme { Theme.defaultTheme() }

    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        view.tintColor = self.theme["listTextColor"]

        tableView.backgroundColor = theme["backgroundColor"]
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]

        tableView.reloadData()
    }
}
