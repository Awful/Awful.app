//  DataStore.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

public final class DataStore: NSObject {
    /// A directory in which the store is saved. Since stores can span multiple files, a directory is required.
    let storeDirectoryURL: NSURL
    
    /// A main-queue-concurrency-type context that is automatically saved when the application enters the background.
    public let mainManagedObjectContext: NSManagedObjectContext
    
    private let storeCoordinator: NSPersistentStoreCoordinator
    private let lastModifiedObserver: LastModifiedContextObserver
    
    /**
    :param: storeDirectoryURL A directory to save the store. Created if it doesn't already exist. The directory will be excluded from backups to iCloud or iTunes.
    */
    public init(storeDirectoryURL: NSURL, modelURL: NSURL) {
        self.storeDirectoryURL = storeDirectoryURL
        mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        let model = NSManagedObjectModel(contentsOfURL: modelURL)!
        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        mainManagedObjectContext.persistentStoreCoordinator = storeCoordinator
        lastModifiedObserver = LastModifiedContextObserver(managedObjectContext: mainManagedObjectContext)
        super.init()
        
        loadPersistentStore()
        let noteCenter = NSNotificationCenter.defaultCenter()
        noteCenter.addObserver(self, selector: "applicationDidEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        noteCenter.addObserver(self, selector: "applicationDidBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func applicationDidEnterBackground(notification: NSNotification) {
        invalidatePruneTimer()
        
        var error: NSError?
        if !mainManagedObjectContext.save(&error) {
            fatalError("error saving main managed object context: \(error!)")
        }
    }
    
    @objc private func applicationDidBecomeActive(notification: NSNotification) {
        invalidatePruneTimer()
        // Since pruning could potentially take a noticeable amount of time, and there's no real rush, let's schedule it for a little bit after becoming active.
        pruneTimer = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: "pruneTimerDidFire:", userInfo: nil, repeats: false)
    }
    
    private var pruneTimer: NSTimer?
    
    private func invalidatePruneTimer() {
        pruneTimer?.invalidate()
        pruneTimer = nil
    }
    
    @objc private func pruneTimerDidFire(timer: NSTimer) {
        pruneTimer = nil
        prune()
    }
    
    private var persistentStore: NSPersistentStore?
    
    private func loadPersistentStore() {
        assert(persistentStore == nil, "persistent store already loaded")
        
        let fileManager = NSFileManager.defaultManager()
        var error: NSError?
        if !fileManager.createDirectoryAtURL(storeDirectoryURL, withIntermediateDirectories: true, attributes: nil, error: &error) {
            fatalError("could not create directory at \(storeDirectoryURL): \(error!)")
        }
        if !storeDirectoryURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey, error: &error) {
            NSLog("[%@ %@] failed to exclude %@ from backup. Error: %@", reflect(self).summary, __FUNCTION__, storeDirectoryURL, error!)
        }
        
        let storeURL = storeDirectoryURL.URLByAppendingPathComponent("AwfulCache.sqlite")
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        persistentStore = storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options, error: &error)
        if persistentStore == nil {
            if error!.domain == NSCocoaErrorDomain {
                switch error!.code {
                case NSMigrationMissingSourceModelError, NSMigrationMissingMappingModelError:
                    fatalError("automatic migration failed at \(storeURL): \(error!)")
                default:
                    break
                }
            }
            fatalError("could not load persistent store at \(storeURL): \(error!)")
        }
    }
    
    private var operationQueue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
        }()
    
    func prune() {
        let pruner = CachePruner(managedObjectContext: mainManagedObjectContext)
        operationQueue.addOperation(pruner)
    }
    
    public func deleteStoreAndReset() {
        invalidatePruneTimer()
        operationQueue.cancelAllOperations()
        
        NSNotificationCenter.defaultCenter().postNotificationName(DataStoreWillResetNotification, object: self)
        
        mainManagedObjectContext.reset()
        
        var error: NSError?
        if let persistentStore = persistentStore {
            if !storeCoordinator.removePersistentStore(persistentStore, error: &error) {
                NSLog("[%@ %@] error removing store at %@: %@", reflect(self).summary, __FUNCTION__, persistentStore.URL!, error!)
            }
            self.persistentStore = nil
        }
        assert(storeCoordinator.persistentStores.isEmpty, "unexpected persistent stores remain after reset")
        
        if !NSFileManager.defaultManager().removeItemAtURL(storeDirectoryURL, error: &error) {
            NSLog("[%@ %@] error deleting store directory %@: %@", reflect(self).summary, __FUNCTION__, storeDirectoryURL, error!)
        }
        
        loadPersistentStore()
        
        NSNotificationCenter.defaultCenter().postNotificationName(DataStoreDidResetNotification, object: self)
    }
}

/// A LastModifiedContextObserver updates the lastModifiedDate attribute (for any objects that have one) whenever its context is saved.
public final class LastModifiedContextObserver: NSObject {
    let managedObjectContext: NSManagedObjectContext
    let relevantEntities: [NSEntityDescription]
    
    public init(managedObjectContext context: NSManagedObjectContext) {
        managedObjectContext = context
        let allEntities = context.persistentStoreCoordinator!.managedObjectModel.entities as! [NSEntityDescription]
        relevantEntities = allEntities.filter { $0.attributesByName["lastModifiedDate"] != nil }
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "contextWillSave:", name: NSManagedObjectContextWillSaveNotification, object: context)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func contextWillSave(notification: NSNotification) {
        let context = notification.object as! NSManagedObjectContext
        let lastModifiedDate = NSDate()
        let insertedOrUpdated = context.insertedObjects.union(context.updatedObjects)
        context.performBlockAndWait {
            let relevantObjects = filter(insertedOrUpdated) { contains(self.relevantEntities, ($0 as! NSManagedObject).entity) }
            (relevantObjects as NSArray).setValue(lastModifiedDate, forKey: "lastModifiedDate")
        }
    }
}

/// Posted when a data store (the notification's object) is about to delete its persistent data. Please relinquish any references you may have to managed objects originating from the data store, as they are now invalid.
let DataStoreWillResetNotification = "Data store will be deleted"

/// Posted once a data store (the notification's object) has deleted its persistent data. Managed objects can once again be inserted into, fetched from, and updated in the data store.
let DataStoreDidResetNotification = "Data store did reset"
