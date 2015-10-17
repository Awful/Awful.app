//  ThreadDataManager.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

final class ThreadDataManager: NSObject, NSFetchedResultsControllerDelegate {
    private(set) var threads: [Thread] = []
    var delegate: ThreadDataManagerDelegate?
    
    private let resultsController: NSFetchedResultsController
    
    init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest) {
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init()
        
        resultsController.delegate = self
        try! resultsController.performFetch()
        
        updateThreads()
    }
    
    /**
    Attempt to work around an issue in iOS 9 where directly casting `resultsController.fetchedObjects as [Thread]` in the `threads` getter crashes with the approximate backtrace:
    
    ```
    0   libobjc.A.dylib             objc_msgSend + 16
    1   CoreFoundation              +[__NSArrayI __new:::] + 100
    2   CoreFoundation              -[NSArray initWithArray:range:copyItems:] + 400
    3   libswiftFoundation.dylib    static Array<A>._forceBridgeFromObjectiveC<A>(NSArray, result : inout [A]?) -> () + 132
    4   libswiftFoundation.dylib    _convertNSArrayToArray<A> (NSArray?) -> [A] + 44
    5   Awful                       ThreadDataManager.threads.getter (ThreadDataManager.swift:9)
    6   Awful                       ThreadDataManagerTableViewAdapter.(reloadViewModels in _2BF64774ADC39A68555F14F42A9ECF92)() -> () (ThreadDataManagerTableViewAdapter.swift:39)
    7   Awful                       protocol witness for ThreadDataManagerDelegate.dataManagerDidChangeContent<A where ...>(ThreadDataManager) -> () in conformance ThreadDataManagerTableViewAdapter (ThreadDataManagerTableViewAdapter.swift:86)
    8   Awful                       @objc ThreadDataManager.controllerDidChangeContent(NSFetchedResultsController) -> () (ThreadDataManager.swift:27)
    9   CoreData                    __77-[NSFetchedResultsController(PrivateMethods) _managedObjectContextDidChange:]_block_invoke + 3976
    ```
    
    The suggestion for this workaround comes from https://forums.developer.apple.com/thread/7628
    */
    private func updateThreads() {
        guard let fetchedObjects = resultsController.fetchedObjects else {
            return
        }
        
        var threads: [Thread] = []
        for object in fetchedObjects {
            let thread = object as! Thread
            threads.append(thread)
        }
        
        self.threads = threads
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    @objc func controllerDidChangeContent(controller: NSFetchedResultsController) {
        updateThreads()
        delegate?.dataManagerDidChangeContent(self)
    }
}

protocol ThreadDataManagerDelegate {
    func dataManagerDidChangeContent(dataManager: ThreadDataManager)
}
