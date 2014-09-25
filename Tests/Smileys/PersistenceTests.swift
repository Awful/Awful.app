//  PersistenceTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smileys
import XCTest

class PersistenceTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = inMemoryDataStack()
    }
    
    func testInsertingSmiley() {
        context.performBlockAndWait {
            let smiley = Smiley(managedObjectContext: self.context)
            smiley.text = ":wotwot:"
            smiley.metadata.lastUseDate = NSDate()
            var error: NSError?
            XCTAssert(self.context.save(&error), "context save error: \(error)")
        }
    }
    
    func testRetrievingSmiley() {
        context.performBlockAndWait {
            let smiley = Smiley(managedObjectContext: self.context)
            smiley.text = ":wotwot:"
            let date = NSDate()
            smiley.metadata.lastUseDate = date
            self.context.save(nil)
            
            let fetchRequest = NSFetchRequest(entityName: "Smiley")
            fetchRequest.predicate = NSPredicate(format: "text = %@", ":wotwot:")
            var error: NSError?
            let results = self.context.executeFetchRequest(fetchRequest, error: &error) as [Smiley]!
            XCTAssert(results != nil, "fetch error: \(error)")
            let retrieved = results[0]
            XCTAssertEqual(retrieved.metadata.lastUseDate!, date, "same metadata fetched as inserted")
        }
    }
    
}
