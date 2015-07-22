//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

// Without import UIKit somewhere in this test bundle, it refuses to load. Nothing here actually needs UIKit.
import UIKit

func fetchAll<T: AwfulManagedObject>(type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> [T] {
    let fetchRequest = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    var results : [T] = []
    do {
        results = try context.executeFetchRequest(fetchRequest) as! [T]
    }
    catch {
        fatalError("error fetching: \(error)")
    }
    return results
}

func fetchOne<T: AwfulManagedObject>(type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> T? {
    let fetchRequest = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    fetchRequest.fetchLimit = 1
    var results : [T] = []
    do {
        results = try context.executeFetchRequest(fetchRequest) as! [T]
    }
    catch {
        fatalError("error fetching: \(error)")
    }
    
    return results.first
}

func fixtureNamed(basename: String) -> HTMLDocument {
    let fixtureURL = NSBundle(forClass: ScrapingTestCase.self).URLForResource(basename, withExtension: "html", subdirectory: "Fixtures")!
    var fixtureHTML : NSString = NSString()
    do {
        fixtureHTML = try NSString(contentsOfURL: fixtureURL, encoding: NSWindowsCP1252StringEncoding)
    }
    catch {
        fatalError("error loading fixture from \(fixtureURL): \(error)")
    }
    
    return HTMLDocument(string: fixtureHTML as String?)
}
