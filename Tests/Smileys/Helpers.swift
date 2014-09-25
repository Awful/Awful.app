//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation
import Smileys

func inMemoryDataStack() -> NSManagedObjectContext {
    let modelURL = NSBundle(forClass: Smiley.self).URLForResource("Smileys", withExtension: "momd")
    let model = NSManagedObjectModel(contentsOfURL: modelURL!)
    let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    var error: NSError? = nil
    let store = storeCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
    assert(store != nil, "error adding in-memory store: \(error)")
    let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    context.persistentStoreCoordinator = storeCoordinator
    return context
}
