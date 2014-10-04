//  PersistenceTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smilies
import XCTest

class PersistenceTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = inMemoryDataStack()
    }
    
    func testInsertingSmilie() {
        context.performBlockAndWait {
            let smilie = Smilie(managedObjectContext: self.context)
            smilie.text = ":wotwot:"
            smilie.metadata.lastUseDate = NSDate()
            var error: NSError?
            XCTAssert(self.context.save(&error), "context save error: \(error)")
        }
    }
    
    func testRetrievingSmilie() {
        context.performBlockAndWait {
            let smilie = Smilie(managedObjectContext: self.context)
            smilie.text = ":wotwot:"
            let date = NSDate()
            smilie.metadata.lastUseDate = date
            self.context.save(nil)
            
            let fetchRequest = NSFetchRequest(entityName: "Smilie")
            fetchRequest.predicate = NSPredicate(format: "text = %@", ":wotwot:")
            var error: NSError?
            let results = self.context.executeFetchRequest(fetchRequest, error: &error) as [Smilie]!
            XCTAssert(results != nil, "fetch error: \(error)")
            let retrieved = results[0]
            XCTAssertEqual(retrieved.metadata.lastUseDate!, date, "same metadata fetched as inserted")
        }
    }
    
}
