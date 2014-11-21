//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Awful

func fetchAll<T: AwfulManagedObject>(type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> [T] {
    let fetchRequest = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    var error: NSError?
    let results = context.executeFetchRequest(fetchRequest, error: &error) as [T]!
    assert(results != nil, "error fetching: \(error!)")
    return results
}

func fetchOne<T: AwfulManagedObject>(type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> T? {
    let fetchRequest = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    fetchRequest.fetchLimit = 1
    var error: NSError?
    let results = context.executeFetchRequest(fetchRequest, error: &error) as [T]!
    assert(results != nil, "error fetching: \(error!)")
    return results.first
}

func fixtureNamed(basename: String) -> HTMLDocument {
    let fixtureURL = NSBundle(forClass: ScrapingTestCase.self).URLForResource(basename, withExtension: "html", subdirectory: "Fixtures")!
    var error: NSError?
    let fixtureHTML = NSString(contentsOfURL: fixtureURL, encoding: NSWindowsCP1252StringEncoding, error:&error)
    assert(fixtureHTML != nil, "error loading fixture from \(fixtureURL): \(error!)")
    return HTMLDocument(string: fixtureHTML)
}
