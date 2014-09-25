//  ScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smileys
import XCTest

class ScrapingTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    lazy var fixture: WebArchive = {
        let URL = NSBundle(forClass: ScrapingTests.self).URLForResource("showsmileys", withExtension: "webarchive")
        return WebArchive(URL: URL!)
    }()

    override func setUp() {
        super.setUp()
        context = inMemoryDataStack()
    }
    
    private func scrapeAndSave() {
        var error: NSError?
        let ok = scrapeSmileys(HTML: fixture.mainFrameHTML, intoManagedObjectContext: context, &error)
        XCTAssert(ok, "scrape and save error \(error)")
    }

    func testSections() {
        scrapeAndSave()
        
        let request = NSFetchRequest(entityName: "Smiley")
        request.resultType = .DictionaryResultType
        request.propertiesToFetch = ["section"]
        request.returnsDistinctResults = true // seemingly ignored for NSInMemoryStore
        var error: NSError?
        let resultDictionaries = context.executeFetchRequest(request, error: &error) as NSArray!
        XCTAssert(resultDictionaries != nil, "fetching got \(error)")
        
        let results = resultDictionaries.valueForKeyPath("@distinctUnionOfObjects.section") as [String]
        XCTAssertEqual(sorted(results), sorted(["Basic Smilies", "Mostly text", "Witty", "Flags and other nationalist crap", "TV, Movies, Games, & Comics", "Horrible & retarded shit we can't wait to delete", "Hey everybody I'm on drugs!", "New / Uncategorized"]))
    }
    
    func testWotWot() {
        scrapeAndSave()
        
        let request = NSFetchRequest(entityName: "Smiley")
        request.predicate = NSPredicate(format: "text = %@", ":wotwot:")
        var error: NSError?
        let results = context.executeFetchRequest(request, error: &error) as [Smiley]!
        XCTAssert(results != nil, "fetching got \(error)")
        XCTAssertEqual(results.count, 1)
        
        let smiley = results[0]
        XCTAssertEqual(smiley.summary!, "it is a duck emoticon")
        XCTAssert(smiley.imageURL!.hasSuffix("emot-wotwot.gif"))
    }

}

class WebArchive {
    private let plist: NSDictionary
    
    init(URL: NSURL) {
        let stream = NSInputStream(URL: URL)
        stream.open()
        var error: NSError?
        let plist = NSPropertyListSerialization.propertyListWithStream(stream, options: 0, format: nil, error: &error) as NSDictionary!
        assert(plist != nil, "error loading webarchive at \(URL): \(error)")
        self.plist = plist
    }
    
    var mainFrameHTML: String {
        get {
            let mainResource = plist["WebMainResource"] as NSDictionary
            let data = mainResource["WebResourceData"] as NSData
            return NSString(data: data, encoding: NSUTF8StringEncoding)
        }
    }
}
