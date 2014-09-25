//  PersistenceTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smileys
import XCTest

class PersistenceTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    lazy var model: NSManagedObjectModel = {
        let modelURL = NSBundle(forClass: Smiley.self).URLForResource("Smileys", withExtension: "momd")
        return NSManagedObjectModel(contentsOfURL: modelURL!)
    }()
    
    override func setUp() {
        super.setUp()
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        var error: NSError? = nil
        let store = storeCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
        assert(store != nil, "error adding in-memory store: \(error)")
        context = NSManagedObjectContext()
        context.persistentStoreCoordinator = storeCoordinator
    }
    
    func testInsertingSmiley() {
        let smiley = NSEntityDescription.insertNewObjectForEntityForName("Smiley", inManagedObjectContext: context) as Smiley
        smiley.text = ":wotwot:"
        smiley.metadata.lastUseDate = NSDate()
        var error: NSError?
        XCTAssert(context.save(&error), "context save error: \(error)")
    }
    
    func testRetrievingSmiley() {
        let smiley = NSEntityDescription.insertNewObjectForEntityForName("Smiley", inManagedObjectContext: context) as Smiley
        smiley.text = ":wotwot:"
        let date = NSDate()
        smiley.metadata.lastUseDate = date
        context.save(nil)
        
        let fetchRequest = NSFetchRequest(entityName: "Smiley")
        fetchRequest.predicate = NSPredicate(format: "text = %@", ":wotwot:")
        var error: NSError?
        let results = context.executeFetchRequest(fetchRequest, error: &error) as [Smiley]!
        XCTAssert(results != nil, "fetch error: \(error)")
        let retrieved = results[0]
        XCTAssertEqual(retrieved.metadata.lastUseDate!, date, "same metadata fetched as inserted")
    }
    
}
