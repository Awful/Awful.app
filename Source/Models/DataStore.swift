//  DataStore.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

class DataStore: NSObject {
    
    /// A directory in which the store is saved. Since stores can span multiple files, a directory is required.
    let storeDirectoryURL: NSURL
    
    /// A main-queue-concurrency-type context that is automatically saved when the application enters the background.
    let mainManagedObjectContext: NSManagedObjectContext
    
    private let storeCoordinator: NSPersistentStoreCoordinator
    
    /**
    :param: storeDirectoryURL A directory to save the store. Created if it doesn't already exist. The directory will be excluded from backups to iCloud or iTunes.
    */
    init(storeDirectoryURL: NSURL, modelURL: NSURL) {
        self.storeDirectoryURL = storeDirectoryURL
        mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        let model = NSManagedObjectModel(contentsOfURL: modelURL)!
        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        mainManagedObjectContext.persistentStoreCoordinator = storeCoordinator
        super.init()
        
        loadPersistentStore()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func didEnterBackground(notification: NSNotification) {
        var error: NSError?
        if !mainManagedObjectContext.save(&error) {
            fatalError("error saving main managed object context: \(error!)")
        }
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
                    break;
                }
            }
            fatalError("could not load persistent store at \(storeURL): \(error!)")
        }
    }
    
    func deleteStoreAndReset() {
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

/// Posted when a data store (the notification's object) is about to delete its persistent data. Please relinquish any references you may have to managed objects originating from the data store, as they are now invalid.
let DataStoreWillResetNotification = "Data store will be deleted"

/// Posted once a data store (the notification's object) has deleted its persistent data. Managed objects can once again be inserted into, fetched from, and updated in the data store.
let DataStoreDidResetNotification = "Data store did reset"
