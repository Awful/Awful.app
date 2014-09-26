//  ScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smileys
import XCTest

class ScrapingTests: XCTestCase {
    
    let fixture = WebArchive.loadFromFixture()
    var scraper: SmileyScraper!

    override func setUp() {
        super.setUp()
        scraper = SmileyScraper(managedObjectContext: inMemoryDataStack())
    }
    
    private func scrapeAndSave() {
        var error: NSError?
        let ok = scraper.scrapeSmileys(HTML: fixture.mainFrameHTML, error: &error)
        XCTAssert(ok, "scrape and save error \(error)")
    }

    func testSections() {
        scrapeAndSave()
        
        let request = NSFetchRequest(entityName: "Smiley")
        request.resultType = .DictionaryResultType
        request.propertiesToFetch = ["section"]
        request.returnsDistinctResults = true // seemingly ignored for NSInMemoryStore
        var error: NSError?
        var resultDictionaries: NSArray! = nil
        scraper.managedObjectContext.performBlockAndWait {
            resultDictionaries = self.scraper.managedObjectContext.executeFetchRequest(request, error: &error) as NSArray!
        }
        XCTAssert(resultDictionaries != nil, "fetching got \(error)")
        
        let results = resultDictionaries.valueForKeyPath("@distinctUnionOfObjects.section") as [String]
        XCTAssertEqual(sorted(results), sorted(["Basic Smilies", "Mostly text", "Witty", "Flags and other nationalist crap", "TV, Movies, Games, & Comics", "Horrible & retarded shit we can't wait to delete", "Hey everybody I'm on drugs!", "New / Uncategorized"]))
    }
    
    func testWotWot() {
        scrapeAndSave()
        
        let request = NSFetchRequest(entityName: "Smiley")
        request.predicate = NSPredicate(format: "text = %@", ":wotwot:")
        var error: NSError?
        var results: [Smiley]! = nil
        scraper.managedObjectContext.performBlockAndWait {
            results = self.scraper.managedObjectContext.executeFetchRequest(request, error: &error) as [Smiley]!
        }
        XCTAssert(results != nil, "fetching got \(error)")
        XCTAssertEqual(results.count, 1)
        
        let smiley = results[0]
        XCTAssertEqual(smiley.summary!, "it is a duck emoticon")
        XCTAssert(smiley.imageURL!.hasSuffix("emot-wotwot.gif"))
    }

}

