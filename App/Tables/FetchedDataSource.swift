//  FetchedDataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

class FetchedDataSource<DataType: NSManagedObject>: NSObject, DataSource, NSFetchedResultsControllerDelegate {
    let fetchedResultsController: NSFetchedResultsController<DataType>
    weak var delegate: DataSourceDelegate?
    
    init(fetchRequest: NSFetchRequest<DataType>, managedObjectContext: NSManagedObjectContext, sectionNameKeyPath: String?) {
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        super.init()
        
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            NSLog("[\(Mirror(reflecting: self)) \(#function)] fetch did fail: \(error)")
        }
    }
    
    func userDrivenChange(_ changes: () -> Void) {
        ignoreUpdates = true
        changes()
        fetchedResultsController.managedObjectContext.processPendingChanges()
        ignoreUpdates = false
    }
    
    fileprivate var ignoreUpdates = false
    
    fileprivate var storedUpdates: [(DataSourceDelegate) -> Void] = []
    
    fileprivate func storeUpdate(_ update: @escaping (DataSourceDelegate) -> Void) {
        if !ignoreUpdates {
            storedUpdates.append(update)
        }
    }
    
    // MARK: DataSource
    
    var numberOfSections: Int {
        return fetchedResultsController.sections!.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("subclass implementation please")
    }
    
    func itemAtIndexPath(_ indexPath: IndexPath) -> AnyObject {
        return fetchedResultsController.object(at: indexPath)
    }
    
    func indexPathsForItem(_ item: AnyObject) -> [IndexPath] {
        if let indexPath = fetchedResultsController.indexPath(forObject: item as! DataType) {
            return [indexPath]
        } else {
            return []
        }
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    func controller(_: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at oldIndexPath: IndexPath?, for change: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        storeUpdate { delegate in
            switch change {
            case .insert:
                delegate.dataSource?(self, didInsertItemsAtIndexPaths: [newIndexPath!])
            case .delete:
                delegate.dataSource?(self, didRemoveItemsAtIndexPaths: [oldIndexPath!])
            case .update:
                delegate.dataSource?(self, didRefreshItemsAtIndexPaths: [oldIndexPath!])
            case .move:
                delegate.dataSource?(self, didRemoveItemsAtIndexPaths: [oldIndexPath!])
                delegate.dataSource?(self, didInsertItemsAtIndexPaths: [newIndexPath!])
            }
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for change: NSFetchedResultsChangeType) {
        storeUpdate { delegate in
            switch change {
            case .insert:
                delegate.dataSource?(self, didInsertSections: IndexSet(integer: sectionIndex))
            case .delete:
                delegate.dataSource?(self, didRemoveSections: IndexSet(integer: sectionIndex))
            case .update, .move:
                NSLog("[\(Mirror(reflecting: self)) \(#function)] unexpected change type \(change.rawValue)")
            }
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let delegate = delegate {
            if !storedUpdates.isEmpty {
                delegate.dataSource?(self, performBatchUpdates: {
                    for update in self.storedUpdates {
                        update(delegate)
                    }
                    }, completion: nil)
            }
        }
        storedUpdates.removeAll()
    }
}
