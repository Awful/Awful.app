//  FetchedDataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

class FetchedDataSource: NSObject {
    let fetchedResultsController: NSFetchedResultsController
    weak var delegate: DataSourceDelegate?
    
    init(fetchRequest: NSFetchRequest, managedObjectContext: NSManagedObjectContext, sectionNameKeyPath: String?) {
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        super.init()
        
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            NSLog("[\(reflect(self).summary) \(__FUNCTION__)] fetch did fail: \(error)")
        }
    }
    
    func userDrivenChange(changes: () -> Void) {
        ignoreUpdates = true
        changes()
        fetchedResultsController.managedObjectContext.processPendingChanges()
        ignoreUpdates = false
    }
    
    private var ignoreUpdates = false
    
    private var storedUpdates: [(DataSourceDelegate) -> Void] = []
    
    private func storeUpdate(update: (DataSourceDelegate) -> Void) {
        if !ignoreUpdates {
            storedUpdates.append(update)
        }
    }
}

extension FetchedDataSource: DataSource {
    var numberOfSections: Int {
        return fetchedResultsController.sections!.count
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return numberOfSections
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        fatalError("subclass implementation please")
    }
    
    func itemAtIndexPath(indexPath: NSIndexPath) -> AnyObject {
        return fetchedResultsController.objectAtIndexPath(indexPath)
    }
    
    func indexPathsForItem(item: AnyObject) -> [NSIndexPath] {
        if let indexPath = fetchedResultsController.indexPathForObject(item as! NSManagedObject) {
            return [indexPath]
        } else {
            return []
        }
    }
}

extension FetchedDataSource: NSFetchedResultsControllerDelegate {
    func controller(_: NSFetchedResultsController, didChangeObject object: NSManagedObject, atIndexPath oldIndexPath: NSIndexPath?, forChangeType change: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        storeUpdate { delegate in
            switch change {
            case .Insert:
                delegate.dataSource?(self, didInsertItemsAtIndexPaths: [newIndexPath!])
            case .Delete:
                delegate.dataSource?(self, didRemoveItemsAtIndexPaths: [oldIndexPath!])
            case .Update:
                delegate.dataSource?(self, didRefreshItemsAtIndexPaths: [oldIndexPath!])
            case .Move:
                delegate.dataSource?(self, didRemoveItemsAtIndexPaths: [oldIndexPath!])
                delegate.dataSource?(self, didInsertItemsAtIndexPaths: [newIndexPath!])
            }
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType change: NSFetchedResultsChangeType) {
        storeUpdate { delegate in
            switch change {
            case .Insert:
                delegate.dataSource?(self, didInsertSections: NSIndexSet(index: sectionIndex))
            case .Delete:
                delegate.dataSource?(self, didRemoveSections: NSIndexSet(index: sectionIndex))
            case .Update, .Move:
                NSLog("[%@ %@] unexpected change type %@", reflect(self).summary, __FUNCTION__, change.rawValue)
            }
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
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
