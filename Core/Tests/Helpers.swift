//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import HTMLReader

// Without import UIKit somewhere in this test bundle, it refuses to load. Nothing here actually needs UIKit.
import UIKit

func htmlFixture(named basename: String) throws -> HTMLDocument {
    let fixtureURL = Bundle(for: DatabaseUnavailableScrapingTests.self).url(forResource: basename, withExtension: "html", subdirectory: "Fixtures")!
    let string = try String(contentsOf: fixtureURL, encoding: .windowsCP1252)
    return HTMLDocument(string: string)
}

func makeInMemoryStoreContext() -> NSManagedObjectContext {
    let psc = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    try! psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = psc
    return context
}

private let managedObjectModel = NSManagedObjectModel(contentsOf:
    Bundle(for: Announcement.self).url(forResource: "Awful", withExtension: "momd")!)!

func scrapeHTMLFixture<T: ScrapeResult>(_: T.Type, named fixtureName: String) throws -> T {
    return try T(htmlFixture(named: fixtureName), url: URL(string: "https://example.com/?perpage=40"))
}

func scrapeJSONFixture<T: Decodable>(_: T.Type, named fixtureName: String) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let url = Bundle(for: DatabaseUnavailableScrapingTests.self).url(forResource: fixtureName, withExtension: "json", subdirectory: "Fixtures")!
    let data = try Data(contentsOf: url)
    return try decoder.decode(T.self, from: data)
}

func scrapeForm(matchingSelector selector: String, inFixtureNamed fixtureName: String) throws -> Form {
    let doc = try htmlFixture(named: fixtureName)
    return try Form(doc.requiredNode(matchingSelector: selector), url: URL(string: "https://example.com/?perpage=40"))
}

extension Form {
    var textboxes: [Form.Control] {
        return controls.filter { control in
            switch control {
            case .text: return true
            default: return false
            }
        }
    }
}
