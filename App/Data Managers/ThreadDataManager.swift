//  ThreadDataManager.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

final class ThreadDataManager: NSObject, NSFetchedResultsControllerDelegate {
    var threads: [Thread] {
        return resultsController.fetchedObjects as! [Thread]
    }
    var delegate: ThreadDataManagerDelegate?
    
    private let resultsController: NSFetchedResultsController
    
    init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest) {
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init()
        
        resultsController.delegate = self
        try! resultsController.performFetch()
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    @objc func controllerWillChangeContent(controller: NSFetchedResultsController) {
        delegate?.dataManagerWillChangeContent(self)
    }
    
    @objc func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            delegate?.dataManager(self, didInsertRowAtIndexPath: newIndexPath!)
        case .Delete:
            delegate?.dataManager(self, didDeleteRowAtIndexPath: indexPath!)
        case .Move:
            delegate?.dataManager(self, didMoveRowAtIndexPath: indexPath!, toRowAtIndexPath: newIndexPath!)
        case .Update:
            delegate?.dataManager(self, didUpdateRowAtIndexPath: indexPath!)
        }
    }
    
    @objc func controllerDidChangeContent(controller: NSFetchedResultsController) {
        delegate?.dataManagerDidChangeContent(self)
    }
}

protocol ThreadDataManagerDelegate {
    func dataManagerWillChangeContent(dataManager: ThreadDataManager)
    func dataManager(dataManager: ThreadDataManager, didInsertRowAtIndexPath indexPath: NSIndexPath)
    func dataManager(dataManager: ThreadDataManager, didDeleteRowAtIndexPath indexPath: NSIndexPath)
    func dataManager(dataManager: ThreadDataManager, didMoveRowAtIndexPath fromIndexPath: NSIndexPath, toRowAtIndexPath toIndexPath: NSIndexPath)
    func dataManager(dataManager: ThreadDataManager, didUpdateRowAtIndexPath indexPath: NSIndexPath)
    func dataManagerDidChangeContent(dataManager: ThreadDataManager)
}

extension AwfulTableViewController: ThreadDataManagerDelegate {
    func dataManagerWillChangeContent(dataManager: ThreadDataManager) {
        tableView.beginUpdates()
    }
    
    func dataManager(dataManager: ThreadDataManager, didInsertRowAtIndexPath indexPath: NSIndexPath) {
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManager(dataManager: ThreadDataManager, didDeleteRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManager(dataManager: ThreadDataManager, didMoveRowAtIndexPath fromIndexPath: NSIndexPath, toRowAtIndexPath toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }
    
    func dataManager(dataManager: ThreadDataManager, didUpdateRowAtIndexPath indexPath: NSIndexPath) {
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManagerDidChangeContent(dataManager: ThreadDataManager) {
        tableView.endUpdates()
    }
}
