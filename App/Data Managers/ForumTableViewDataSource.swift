//  ForumTableViewDataSource.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

final class ForumTableViewDataSource: NSObject, UITableViewDataSource, FetchedDataManagerDelegate {
    private let tableView: UITableView
    private let cellConfigurator: (ForumTableViewCell, Forum, ViewModel) -> Void
    private let headerThemer: UITableViewCell -> Void
    
    private let favouritesData: FetchedDataManager<ForumMetadata>
    private let forumsData: FetchedDataManager<Forum>
    private var observer: CollapseExpandObserver!
    
    private var models: [Model] = []
    private(set) var lastFavoriteIndex: Int?
    private var skipTableUpdate = false
    var isEmpty: Bool {
        return models.isEmpty
    }
    var hasFavorites: Bool {
        return lastFavoriteIndex != nil
    }
    var didReload: (() -> Void)?
    
    init(tableView: UITableView, managedObjectContext: NSManagedObjectContext, cellConfigurator: (ForumTableViewCell, Forum, ForumTableViewCell.ViewModel) -> Void, headerThemer: UITableViewCell -> Void) {
        self.tableView = tableView
        self.cellConfigurator = cellConfigurator
        self.headerThemer = headerThemer
        
        let fetchFavourites = NSFetchRequest(entityName: ForumMetadata.entityName())
        fetchFavourites.predicate = NSPredicate(format: "favorite == YES")
        fetchFavourites.sortDescriptors = [NSSortDescriptor(key: "favoriteIndex", ascending: true)]
        favouritesData = FetchedDataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchFavourites)
        
        let fetchForums = NSFetchRequest(entityName: Forum.entityName())
        fetchForums.sortDescriptors = [
            NSSortDescriptor(key: "group.index", ascending: true),
            NSSortDescriptor(key: "index", ascending: true)
        ]
        forumsData = FetchedDataManager(managedObjectContext: managedObjectContext, fetchRequest: fetchForums)
        
        super.init()
        
        observer = CollapseExpandObserver(managedObjectContext: managedObjectContext) { [weak self] in
            self?.reloadModels()
        }
        
        favouritesData.delegate = self
        forumsData.delegate = self
        
        withoutInformingTable {
            reloadModels()
        }
    }
    
    private func reloadModels() {
        let oldModels = models
        
        models = []
        let favourites = favouritesData.contents
        if !favourites.isEmpty {
            models.append(.Header("Favorites"))
            models += favourites[0 ..< favourites.endIndex - 1].map { .Favorite(ViewModel(favorite: $0.forum), $0.forum) }
            let last = favourites.last!
            models.append(.Favorite(ViewModel(favorite: last.forum, showSeparator: false), last.forum))
        }
        lastFavoriteIndex = models.isEmpty ? nil : models.count - 1
        
        var currentGroup: ForumGroup? = nil
        var lastForumsInGroup: Set<Forum> = []
        for forum in forumsData.contents.reverse() where forum.group != currentGroup {
            lastForumsInGroup.insert(forum)
            currentGroup = forum.group
        }
        
        currentGroup = nil
        for forum in forumsData.contents {
            if let group = forum.group where group != currentGroup,
                let name = group.name
            {
                currentGroup = group
                models.append(.Header(name))
            }

            if forum.isVisible {
                models.append(.Forum(ViewModel(forum: forum, showSeparator: !lastForumsInGroup.contains(forum)), forum))
            }
        }
        
        guard !skipTableUpdate else { return }
        let delta = oldModels.delta(models)
        guard !delta.isEmpty else { return }
        
        let pathify: Int -> NSIndexPath = { NSIndexPath(forRow: $0, inSection: 0) }
        tableView.beginUpdates()
        let deletions = delta.deletions.map(pathify)
        tableView.deleteRowsAtIndexPaths(deletions, withRowAnimation: .Fade)
        let insertions = delta.insertions.map(pathify)
        tableView.insertRowsAtIndexPaths(insertions, withRowAnimation: .Fade)
        let moves = delta.moves.map { (pathify($0), pathify($1)) }
        moves.forEach(tableView.moveRowAtIndexPath)
        tableView.endUpdates()
        
        didReload?()
    }
    
    private func withoutInformingTable(@noescape block: () -> Void) {
        skipTableUpdate = true
        block()
        skipTableUpdate = false
    }
    
    func objectAtIndexPath(indexPath: NSIndexPath) -> Forum? {
        switch models[indexPath.row] {
        case let .Forum(_, forum):
            return forum
            
        case let .Favorite(_, forum):
            return forum
            
        case .Header:
            return nil
        }
    }
    
    func indexPathForObject(object: Forum) -> NSIndexPath? {
        for (i, model) in models.enumerate() where model.forum == object {
            return NSIndexPath(forRow: i, inSection: 0)
        }
        return nil
    }
    
    static let headerReuseIdentifier = "Header"
    
    // MARK: FetchedDataManagerDelegate
    
    func dataManagerDidChangeContent<Object: NSManagedObject>(dataManager: FetchedDataManager<Object>) {
        reloadModels()
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let model = models[indexPath.row]
        if case let .Header(title) = model {
            let cell = tableView.dequeueReusableCellWithIdentifier(ForumTableViewDataSource.headerReuseIdentifier, forIndexPath: indexPath)
            cell.textLabel?.text = title
            headerThemer(cell)
            return cell
        }
        
        guard let viewModel = model.viewModel else { fatalError("forum model missing view model") }
        guard let forum = model.forum else { fatalError("forum model missing view forum") }
        guard let cell = tableView.dequeueReusableCellWithIdentifier(ForumTableViewCell.identifier, forIndexPath: indexPath) as? ForumTableViewCell else {
            fatalError("wrong cell type for forum")
        }
        cellConfigurator(cell, forum, viewModel)
        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        guard case .Favorite = models[indexPath.row] else { return false }
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard case let .Favorite(_, forum) = models[indexPath.row] else { fatalError("can't delete a non-favorite") }
        forum.metadata.favorite = false
        try! forum.managedObjectContext!.save()
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        guard case .Favorite = models[indexPath.row] else { return false }
        return true
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        withoutInformingTable {
            var favorites = favouritesData.contents
            let moved = favorites.removeAtIndex(fromIndexPath.row - 1)
            favorites.insert(moved, atIndex: toIndexPath.row - 1)
            for (i, metadata) in favorites.enumerate() {
                metadata.favoriteIndex = Int32(i)
            }
            try! favorites[0].managedObjectContext?.save()
        }
    }
}

private typealias ViewModel = ForumTableViewCell.ViewModel

private enum Model: Equatable {
    case Header(String)
    case Forum(ViewModel, AwfulCore.Forum)
    case Favorite(ViewModel, AwfulCore.Forum)

    var forum: AwfulCore.Forum? {
        switch self {
        case .Header:
            return nil
            
        case let .Forum(_, forum):
            return forum
            
        case let .Favorite(_, forum):
            return forum
        }
    }
    
    var viewModel: ViewModel? {
        switch self {
        case .Header:
            return nil
            
        case let .Forum(viewModel, _):
            return viewModel
            
        case let .Favorite(viewModel, _):
            return viewModel
        }
    }
}

private func ==(lhs: Model, rhs: Model) -> Bool {
    switch (lhs, rhs) {
    case let (.Header(lhsName), .Header(rhsName)):
        return lhsName == rhsName
        
    case let (.Favorite(lhsForum, _), .Favorite(rhsForum, _)):
        return lhsForum == rhsForum
        
    case let (.Forum(lhsForum, _), .Forum(rhsForum, _)):
        return lhsForum == rhsForum
        
    default:
        return false
    }
}

extension Forum {
    var ancestors: AnySequence<Forum> {
        var current = parentForum
        return AnySequence {
            return anyGenerator {
                let next = current
                current = current?.parentForum
                return next
            }
        }
    }
    
    private var isVisible: Bool {
        return ancestors.all { $0.metadata.showsChildrenInForumList }
    }
}

extension ForumTableViewCell.ViewModel {
    private init(forum: Forum, showSeparator: Bool) {
        favorite = forum.metadata.favorite ? .Hidden : .Off
        name = forum.name ?? ""
        childSubforumCount = forum.childForums.count ?? 0
        if forum.childForums.count == 0 {
            canExpand = .Hidden
        } else {
            canExpand = forum.metadata.showsChildrenInForumList ? .On : .Off
        }
        indentationLevel = Array(forum.ancestors).count
        self.showSeparator = showSeparator
    }
    
    private init(favorite forum: Forum, showSeparator: Bool = true) {
        favorite = .On
        name = forum.name ?? ""
        childSubforumCount = 0
        canExpand = .Hidden
        indentationLevel = 0
        self.showSeparator = showSeparator
    }
}

private class CollapseExpandObserver {
    private let managedObjectContext: NSManagedObjectContext
    private let changeBlock: () -> Void
    
    init(managedObjectContext: NSManagedObjectContext, changeBlock: () -> Void) {
        self.managedObjectContext = managedObjectContext
        self.changeBlock = changeBlock
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "objectsDidChange:", name: NSManagedObjectContextObjectsDidChangeNotification, object: managedObjectContext)
    }
    
    @objc private func objectsDidChange(notification: NSNotification) {
        guard let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> else { return }
        guard updatedObjects
            .filter({ $0 is ForumMetadata })
            .map({ $0.changedValuesForCurrentEvent() })
            .any({ $0.keys.contains("showsChildrenInForumList") })
            else { return }
        changeBlock()
    }
}
