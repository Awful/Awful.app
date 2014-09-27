//  SmileyDataStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

public class SmileyDataStack: NSObject {
   
    public let managedObjectContext: NSManagedObjectContext
    
    public override init() {
        let bundle = NSBundle(forClass: SmileyDataStack.self)
        let modelURL = bundle.URLForResource("Smileys", withExtension: "momd")
        let model = NSManagedObjectModel(contentsOfURL: modelURL!)
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let readOnlyStoreURL = bundle.URLForResource("BundledSmileys", withExtension: "sqlite")
        let options = [NSReadOnlyPersistentStoreOption: true]
        var error: NSError? = nil
        let store = storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: "NoMetadata", URL: readOnlyStoreURL, options: options, error: &error)
        assert(store != nil, "error loading read-only smiley store: \(error)")
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }
    
}
