//  SmilieDataStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

public class SmilieDataStack: NSObject {
   
    public let managedObjectContext: NSManagedObjectContext
    
    public override init() {
        let bundle = NSBundle(forClass: SmilieDataStack.self)
        let modelURL = bundle.URLForResource("Smilies", withExtension: "momd")
        let model = NSManagedObjectModel(contentsOfURL: modelURL!)
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let readOnlyStoreURL = bundle.URLForResource("BundledSmilies", withExtension: "sqlite")
        let options = [NSReadOnlyPersistentStoreOption: true]
        var error: NSError? = nil
        let store = storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: "NoMetadata", URL: readOnlyStoreURL, options: options, error: &error)
        assert(store != nil, "error loading read-only smilie store: \(error)")
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }
    
}
