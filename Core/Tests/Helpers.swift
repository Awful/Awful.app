//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

// Without import UIKit somewhere in this test bundle, it refuses to load. Nothing here actually needs UIKit.
import UIKit

func fetchAll<T: AwfulManagedObject>(_ type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> [T] {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    var results : [T] = []
    do {
        results = try context.fetch(fetchRequest) as! [T]
    }
    catch {
        fatalError("error fetching: \(error)")
    }
    return results
}

func fetchOne<T: AwfulManagedObject>(_ type: T.Type, inContext context: NSManagedObjectContext, matchingPredicate predicate: NSPredicate? = nil) -> T? {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: T.entityName())
    fetchRequest.predicate = predicate
    fetchRequest.fetchLimit = 1
    var results : [T] = []
    do {
        results = try context.fetch(fetchRequest) as! [T]
    }
    catch {
        fatalError("error fetching: \(error)")
    }
    
    return results.first
}

func fixtureNamed(_ basename: String) -> HTMLDocument {
    let fixtureURL = Bundle(for: ScrapingTestCase.self).url(forResource: basename, withExtension: "html", subdirectory: "Fixtures")!
    var fixtureHTML : NSString = NSString()
    do {
        fixtureHTML = try NSString(contentsOf: fixtureURL, encoding: String.Encoding.windowsCP1252.rawValue)
    }
    catch {
        fatalError("error loading fixture from \(fixtureURL): \(error)")
    }
    
    return HTMLDocument(string: (fixtureHTML as String?)!)
}

func scrapeFixture<T: ScrapeResult>(named fixtureName: String) throws -> T {
    return try T(fixtureNamed(fixtureName), url: URL(string: "https://example.com/?perpage=40"))
}

func makeUTCDefaultTimeZone() {
    NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
}
