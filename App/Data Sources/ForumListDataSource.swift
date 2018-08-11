//  ForumListDataSource.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get()

final class ForumListDataSource: NSObject {
    private let announcementsController: NSFetchedResultsController<Announcement>
    private var deferredDeletes: [IndexPath] = []
    private var deferredInserts: [IndexPath] = []
    private var deferredSectionDeletes = IndexSet()
    private var deferredSectionInserts = IndexSet()
    private var deferredUpdates: [IndexPath] = []
    weak var delegate: ForumListDataSourceDelegate?
    private let favoriteForumsController: NSFetchedResultsController<ForumMetadata>
    private let forumsController: NSFetchedResultsController<Forum>
    private var ignoreControllerUpdates = false
    private let tableView: UITableView

    private(set) lazy var undoManager: UndoManager = {
        let undoManager = UndoManager()
        undoManager.levelsOfUndo = 1
        return undoManager
    }()
    
    init(managedObjectContext: NSManagedObjectContext, tableView: UITableView) throws {
        let announcementsRequest = NSFetchRequest<Announcement>(entityName: Announcement.entityName())
        announcementsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        announcementsController = NSFetchedResultsController(
            fetchRequest: announcementsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        let favoriteForumsRequest = NSFetchRequest<ForumMetadata>(entityName: ForumMetadata.entityName())
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        favoriteForumsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        let forumsRequest = NSFetchRequest<Forum>(entityName: Forum.entityName())
        forumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(Forum.metadata.visibleInForumList))
        forumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true), // section
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]
        forumsController = NSFetchedResultsController(
            fetchRequest: forumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: #keyPath(Forum.group.sectionIdentifier),
            cacheName: nil)
        
        self.tableView = tableView
        super.init()
        
        try announcementsController.performFetch()
        try favoriteForumsController.performFetch()
        try forumsController.performFetch()
        
        tableView.dataSource = self
        tableView.estimatedRowHeight = ForumListCell.estimatedHeight
        tableView.register(ForumListCell.self, forCellReuseIdentifier: forumCellIdentifier)
        
        announcementsController.delegate = self
        favoriteForumsController.delegate = self
        forumsController.delegate = self
    }
    
    private var resultsControllers: [NSFetchedResultsController<NSFetchRequestResult>] {
        return [announcementsController as! NSFetchedResultsController<NSFetchRequestResult>,
                favoriteForumsController as! NSFetchedResultsController<NSFetchRequestResult>,
                forumsController as! NSFetchedResultsController<NSFetchRequestResult>]
    }
    
    private func controllerAtGlobalSection(_ globalSection: Int) -> (controller: NSFetchedResultsController<NSFetchRequestResult>, localSection: Int) {
        var section = globalSection
        for controller in resultsControllers {
            guard let sections = controller.sections else { continue }
            if section < sections.count {
                return (controller: controller, localSection: section)
            }
            section -= sections.count
        }
        
        fatalError("section index out of bounds: \(section)")
    }
    
    private func globalSectionForLocalSection(_ localSection: Int, in controller: NSFetchedResultsController<NSFetchRequestResult>) -> Int {
        var section = localSection
        for earlierController in resultsControllers {
            guard controller !== earlierController else { break }
            guard let sections = earlierController.sections else { continue }
            section += sections.count
        }
        return section
    }

    private func performIgnoringControllerUpdates(_ block: () -> Void) {
        ignoreControllerUpdates = true
        block()
        ignoreControllerUpdates = false
    }
}

extension ForumListDataSource {
    /// - Returns: The `Announcement` or `Forum` at `indexPath`.
    func item(at indexPath: IndexPath) -> Any {
        let (controller, localSection: section) = controllerAtGlobalSection(indexPath.section)
        switch controller.object(at: IndexPath(row: indexPath.row, section: section)) {
        case let announcement as Announcement:
            return announcement

        case let forum as Forum:
            return forum

        case let metadata as ForumMetadata:
            return metadata.forum

        default:
            fatalError("item of unknown type in forums list")
        }
    }
}

extension ForumListDataSource {
    func titleForSection(_ section: Int) -> String {
        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(section)
        if controller === announcementsController {
            return LocalizedString("forums-list.announcements-section-title")
        }
        else if controller === favoriteForumsController {
            return LocalizedString("forums-list.favorite-forums.section-title")
        }
        else if controller === forumsController {
            guard let sections = controller.sections else {
                fatalError("something's wrong with the fetched results controller")
            }

            let sectionIdentifier = sections[localSection].name
            return String(sectionIdentifier.dropFirst(ForumGroup.sectionIdentifierIndexLength + 1))
        }
        else {
            fatalError("unknown results controller \(controller)")
        }
    }
}

extension ForumListDataSource {
    var hasFavorites: Bool {
        let count = favoriteForumsController.fetchedObjects?.count ?? 0
        return count > 0
    }

    private var indexPathOfLastFavorite: IndexPath {
        guard let favoriteCount = favoriteForumsController.sections?.first?.numberOfObjects else {
            fatalError("can't figure out how many favorite forums we have")
        }
        let row = favoriteCount > 0 ? favoriteCount - 1 : 0
        let section = globalSectionForLocalSection(0, in: favoriteForumsController as! NSFetchedResultsController<NSFetchRequestResult>)
        return IndexPath(row: row, section: section)
    }
    
    var nextFavoriteIndex: Int32 {
        let last = favoriteForumsController.fetchedObjects?.last
        return last.map { $0.favoriteIndex + 1 } ?? 1
    }
}

extension ForumListDataSource {
    private func updateMetadata(_ metadata: ForumMetadata, setIsFavorite isFavorite: Bool) {
        Log.d("\(isFavorite ? "adding" : "removing") favorite forum \(metadata.forum.name ?? "")")

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
}

extension ForumListDataSource: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard !ignoreControllerUpdates else {
            Log.d("ignoring updates in \(controller)")
            return
        }

        Log.d("beginning to defer updates in \(controller)")
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {

        guard !ignoreControllerUpdates else { return }
        
        Log.d("local section \(sectionIndex) is changing…")
        
        let sectionIndex = globalSectionForLocalSection(sectionIndex, in: controller)
        
        switch type {
        case .delete:
            Log.d("…it's global section \(sectionIndex) and it's getting deleted")
            
            deferredSectionDeletes.insert(sectionIndex)
            
        case .insert:
            Log.d("…it's global section \(sectionIndex) and it's getting inserted")
            
            deferredSectionInserts.insert(sectionIndex)
            
        case .move, .update:
            assertionFailure("why")
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at oldIndexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        guard !ignoreControllerUpdates else { return }
        
        Log.d("did change object at local old = \(oldIndexPath?.description ?? ""), local new = \(newIndexPath?.description ?? "")…")
        
        let oldIndexPath = oldIndexPath.map { IndexPath(row: $0.row, section: globalSectionForLocalSection($0.section, in: controller)) }
        let newIndexPath = newIndexPath.map { IndexPath(row: $0.row, section: globalSectionForLocalSection($0.section, in: controller)) }
        
        switch type {
        case .delete:
            Log.d("…global path = \(oldIndexPath!) and it's getting deleted")
            
            deferredDeletes.append(oldIndexPath!)
            
        case .insert:
            Log.d("…global path = \(newIndexPath!) and it's getting inserted")
            
            deferredInserts.append(newIndexPath!)
            
        case .move:
            Log.d("…global old = \(oldIndexPath!), global new = \(newIndexPath!) and it's moving")
            
            deferredDeletes.append(oldIndexPath!)
            deferredInserts.append(newIndexPath!)
            
        case .update:
            Log.d("…global path = \(oldIndexPath!) and it's getting updated")
            
            deferredUpdates.append(oldIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard !ignoreControllerUpdates else {
            Log.d("done ignoring updates in \(controller)")
            return
        }

        Log.d("done with deferring updates in \(controller)")

        /*
         Yuck. Sorry. I hate delayed performs (or whatever this is called in the era of dispatch queues) but I'm not sure what else to do.

         The problem we're trying to solve here is when multiple FRCs update because of the same change in the context (e.g. adding a favorite forum causes the Favorite Forums FRC to insert a row and also causes the Forums FRC to reload a row). This results in the following sequence of calls, all stemming from whatever call to save/processPendingChanges:

             controllerWillChangeContent(favoriteForumsController)
             controller…
             controllerDidChangeContent(favoriteForumsController)
             controllerWillChangeContent(forumsController)
             controller…
             controllerDidChangeContent(forumsController)

         If we process this normally, we get two un-nested calls to tableView.beginUpdates()/endUpdates(), and that gives us some ugly animations. One way to fix this is to start an overarching tableView.beginUpdates() then nest the consecutive calls within. However, I couldn't think of a good way to tell how many FRCs we expect to update or when we're seeing the last FRC update for the currently-processing notification.

         For the moment, it seems that all FRCs get processed in the same go-round of the run loop. So if we wait a tick, allowing however many FRCs to stack up their updates, then we can process them all at once.
         */
        DispatchQueue.main.async {

            // This does avoid pointless table view calls, but it's also the other half of our workaround for multiple FRCs updating at once: this ensures that only one of multiple scheduled "next tick" calls actually calls tableView.beginUpdates()/endUpdates().
            guard !self.deferredDeletes.isEmpty || !self.deferredInserts.isEmpty || !self.deferredUpdates.isEmpty
                || !self.deferredSectionDeletes.isEmpty || !self.deferredSectionInserts.isEmpty
                else {
                    Log.d("no deferred updates to handle")
                    return
            }

            Log.d("running deferred updates")

            self.tableView.beginUpdates()

            self.tableView.deleteSections(self.deferredSectionDeletes, with: .fade)
            self.tableView.insertSections(self.deferredSectionInserts, with: .fade)

            self.tableView.deleteRows(at: self.deferredDeletes, with: .fade)
            self.tableView.insertRows(at: self.deferredInserts, with: .fade)

            self.tableView.reloadRows(at: self.deferredUpdates, with: .none)

            self.tableView.endUpdates()

            self.deferredDeletes.removeAll()
            self.deferredInserts.removeAll()
            self.deferredSectionDeletes.removeAll()
            self.deferredSectionInserts.removeAll()
            self.deferredUpdates.removeAll()
        }
    }
}

extension ForumListDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return resultsControllers
            .compactMap { $0.sections?.count }
            .reduce(0, +)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(section)
        return controller.sections?[localSection].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return controllerAtGlobalSection(indexPath.section).controller === favoriteForumsController
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(indexPath.section)

        guard let metadata = controller.object(at: IndexPath(row: indexPath.row, section: localSection)) as? ForumMetadata else {
            fatalError("can only delete favorites, expected a ForumMetadata")
        }

        updateMetadata(metadata, setIsFavorite: false)
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return controllerAtGlobalSection(indexPath.section).controller === favoriteForumsController
    }

    // This is actually a UITableViewDelegate method. Don't tell anyone…
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        let favoriteSection = globalSectionForLocalSection(0, in: favoriteForumsController as! NSFetchedResultsController<NSFetchRequestResult>)

        let destinationIndexPath: IndexPath = {
            if proposedDestinationIndexPath.section > favoriteSection {
                return indexPathOfLastFavorite
            }
            else if proposedDestinationIndexPath.section < favoriteSection {
                return IndexPath(row: 0, section: favoriteSection)
            }
            else {
                return proposedDestinationIndexPath
            }
        }()

        Log.d("trying to move \(sourceIndexPath), aiming at \(proposedDestinationIndexPath), ended up at \(destinationIndexPath)")

        return destinationIndexPath
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        Log.d("saving move from \(sourceIndexPath) to \(destinationIndexPath)")

        guard sourceIndexPath != destinationIndexPath else {
            Log.d("…which isn't really a move, so we're done")
            return
        }

        performIgnoringControllerUpdates {
            var metadatas = favoriteForumsController.sections?.first?.objects as? [ForumMetadata] ?? []
            let moved = metadatas.remove(at: sourceIndexPath.row)
            metadatas.insert(moved, at: destinationIndexPath.row)
            zip(metadatas, 1...).forEach { $0.favoriteIndex = Int32($1) }
            try! metadatas.first?.managedObjectContext?.save()
        }
    }

    // This is actually a UITableViewDelegate method.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let viewModel = viewModelForCell(at: indexPath)
        return ForumListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.bounds.width)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: forumCellIdentifier, for: indexPath) as? ForumListCell else {
            fatalError("expected a ForumListCell")
        }

        cell.viewModel = viewModelForCell(at: indexPath)

        return cell
    }

    private func viewModelForCell(at indexPath: IndexPath) -> ForumListCell.ViewModel {
        let controller = controllerAtGlobalSection(indexPath.section).controller
        let theme = delegate?.themeForCells(in: self) ?? Theme.currentTheme

        // Using forum cells to show announcements out of sheer laziness.
        switch item(at: indexPath) {
        case let announcement as Announcement:
            return ForumListCell.ViewModel(
                backgroundColor: theme["listBackgroundColor"]!,
                expansion: .none,
                expansionTintColor: theme["tintColor"]!,
                favoriteStar: announcement.hasBeenSeen ? .hidden : .isFavorite,
                favoriteStarTintColor: theme["tintColor"]!,
                forumName: NSAttributedString(string: announcement.title, attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
                indentationLevel: 0,
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)

        case let forum as Forum where controller === favoriteForumsController:
            return ForumListCell.ViewModel(
                backgroundColor: theme["listBackgroundColor"]!,
                expansion: .none,
                expansionTintColor: theme["tintColor"]!,
                favoriteStar: .isFavorite,
                favoriteStarTintColor: theme["tintColor"]!,
                forumName: NSAttributedString(string: forum.name ?? "", attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
                indentationLevel: 0,
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)

        case let forum as Forum:
            return ForumListCell.ViewModel(
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
                    .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
                indentationLevel: forum.ancestors.reduce(0) { i, _ in i + 1 },
                selectedBackgroundColor: theme["listSelectedBackgroundColor"]!)

        default:
            fatalError("unexpected item \(item) in forum list")
        }
    }
}

protocol ForumListDataSourceDelegate: class {
    func themeForCells(in dataSource: ForumListDataSource) -> Theme
}

private let forumCellIdentifier = "ForumListCell"
