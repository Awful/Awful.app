//  ScrapingTestCase.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore
import CoreData

class ScrapingTestCase: XCTestCase {
    var managedObjectContext: NSManagedObjectContext!
    
    private var storeCoordinator: NSPersistentStoreCoordinator = {
        let modelURL = Bundle(for: AwfulManagedObject.self).urlForResource("Awful", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        return NSPersistentStoreCoordinator(managedObjectModel: model)
        }()
    private var memoryStore: NSPersistentStore!
    
    class func scraperClass() -> AnyClass {
        fatalError("subclass implementation please")
    }
    
    override func setUp() {
        super.setUp()
        
        // The scraper uses the default time zone. To make the test repeatable, we set a known time zone.
        TimeZone.default = TimeZone(forSecondsFromGMT: 0)
        
        do {
            memoryStore = try storeCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        }
        catch {
            fatalError("error adding memory store: \(error)")
        }
        
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }
    
    override func tearDown() {
        managedObjectContext = nil
        do {
            try storeCoordinator.remove(memoryStore)
        }
        catch {
            fatalError("error removing store: \(error)")
        }
        
        super.tearDown()
    }
    
    func scrapeFixtureNamed(fixtureName: String) -> AwfulScraper {
        let document = fixtureNamed(basename: fixtureName)
        let scraperClass = self.dynamicType.scraperClass() as! AwfulScraper.Type
        let scraper = scraperClass.scrape(document, into: managedObjectContext)
        assert(scraper?.error == nil, "error scraping \(scraperClass): \(scraper?.error)")
        return scraper!
    }
}
