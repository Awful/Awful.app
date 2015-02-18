//  ScrapingTestCase.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore
import CoreData

class ScrapingTestCase: XCTestCase {
    var managedObjectContext: NSManagedObjectContext!
    
    private var storeCoordinator: NSPersistentStoreCoordinator = {
        let modelURL = NSBundle(forClass: AwfulManagedObject.self).URLForResource("Awful", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOfURL: modelURL)!
        return NSPersistentStoreCoordinator(managedObjectModel: model)
        }()
    private var memoryStore: NSPersistentStore!
    
    class func scraperClass() -> AnyClass {
        fatalError("subclass implementation please")
    }
    
    override func setUp() {
        super.setUp()
        
        // The scraper uses the default time zone. To make the test repeatable, we set a known time zone.
        NSTimeZone.setDefaultTimeZone(NSTimeZone(forSecondsFromGMT: 0))
        
        var error: NSError?
        memoryStore = storeCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error:&error)
        assert(memoryStore != nil, "error adding memory store: \(error!)")
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }
    
    override func tearDown() {
        managedObjectContext = nil
        var error: NSError?
        let ok = storeCoordinator.removePersistentStore(memoryStore, error:&error)
        assert(ok, "error removing store: \(error!)")
        super.tearDown()
    }
    
    func scrapeFixtureNamed(fixtureName: String) -> AwfulScraper {
        let document = fixtureNamed(fixtureName)
        let scraperClass = self.dynamicType.scraperClass() as AwfulScraper.Type
        let scraper = scraperClass.scrapeNode(document, intoManagedObjectContext: managedObjectContext)
        assert(scraper.error == nil, "error scraping \(scraperClass): \(scraper.error)")
        return scraper
    }
}
