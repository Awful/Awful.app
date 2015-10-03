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
    
    @objc func controllerDidChangeContent(controller: NSFetchedResultsController) {
        delegate?.dataManagerDidChangeContent(self)
    }
}

protocol ThreadDataManagerDelegate {
    func dataManagerDidChangeContent(dataManager: ThreadDataManager)
}
