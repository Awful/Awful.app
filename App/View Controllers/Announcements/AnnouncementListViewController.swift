//  AnnouncementListViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get()

@available(iOS 13.0, *)
final class AnnouncementListViewController: UIViewController {

    private let resultsController: NSFetchedResultsController<Announcement>

    init(managedObjectContext: NSManagedObjectContext) {
        let request = NSFetchRequest<Announcement>(entityName: Announcement.entityName())
        request.fetchBatchSize = 50 // Approximately two screenfuls on an iPad in portrait.
        request.returnsObjectsAsFaults = false
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        resultsController = .init(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init(nibName: nil, bundle: nil)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.hideExtraneousSeparators()
        tableView.register(ForumListCell.self, forCellReuseIdentifier: "Announcement")
        return tableView
    }()

    private enum Section: CaseIterable, Hashable {
        case announcements
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        try! resultsController.performFetch()
        resultsController.delegate = self

        view.addSubview(tableView, constrainEdges: .all)

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

// MARK: Helpers

@available(iOS 13.0, *)
extension AnnouncementListViewController {
    private func makeViewModel(for announcement: Announcement) -> ForumListCell.ViewModel {
        return ForumListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            expansion: .none,
            expansionTintColor: theme["tintColor"]!,
            favoriteStar: announcement.hasBeenSeen ? .hidden : .isFavorite,
            favoriteStarTintColor: theme["tintColor"]!,
            forumName: NSAttributedString(string: announcement.title, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: theme[color: "listTextColor"]!]),
            indentationLevel: 0,
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)
    }
}

// MARK: Results controller

@available(iOS 13.0, *)
extension AnnouncementListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        tableView.performBatchUpdates({
            for change in diff {
                switch change {
                case let .insert(offset: newRow, element: _, associatedWith: oldRow):
                    if let oldRow = oldRow {
                        tableView.deleteRows(at: [IndexPath(row: oldRow, section: 0)], with: .fade)
                        tableView.insertRows(at: [IndexPath(row: newRow, section: 0)], with: .fade)
                    } else {
                        tableView.insertRows(at: [IndexPath(row: newRow, section: 0)], with: .fade)
                    }

                case let .remove(offset: oldRow, element: _, associatedWith: associatedOffset):
                    if associatedOffset == nil {
                        tableView.deleteRows(at: [IndexPath(row: oldRow, section: 0)], with: .fade)
                    }
                }
            }
        }, completion: nil)
    }
}

// MARK: Theme

@available(iOS 13.0, *)
extension AnnouncementListViewController: Themeable {
    var theme: Theme { Theme.defaultTheme() }

    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]

        tableView.backgroundColor = theme["backgroundColor"]
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]

        tableView.reloadData()
    }
}

// MARK: Table view

@available(iOS 13.0, *)
extension AnnouncementListViewController: UITableViewDataSource & UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.fetchedObjects?.count ?? 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let announcement = resultsController.object(at: indexPath)
        let viewModel = makeViewModel(for: announcement)
        return ForumListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.safeAreaFrame.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Announcement", for: indexPath) as! ForumListCell
        let announcement = resultsController.object(at: indexPath)
        cell.viewModel = makeViewModel(for: announcement)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let announcement = resultsController.object(at: indexPath)
        let announcementVC = AnnouncementViewController(announcement: announcement)
        showDetailViewController(announcementVC, sender: self)
    }
}
