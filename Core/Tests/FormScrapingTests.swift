//  FormScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import XCTest

final class FormScrapingTests: XCTestCase {
    private lazy var storeCoordinator: NSPersistentStoreCoordinator = {
        let modelURL = Bundle(for: AwfulManagedObject.self).url(forResource: "Awful", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)
        return NSPersistentStoreCoordinator(managedObjectModel: model)
    }()
    private var memoryStore: NSPersistentStore!
    private var managedObjectContext: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        memoryStore = try! storeCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }

    override func tearDown() {
        managedObjectContext = nil

        try! storeCoordinator.remove(memoryStore)
        memoryStore = nil

        super.tearDown()
    }

    fileprivate func scrapeFormFixtureNamed(_ fixtureName: String) -> AwfulForm {
        let document = fixtureNamed(fixtureName)
        let formElement = document.firstNode(matchingSelector: "form[name='vbform']")
        let form = AwfulForm(element: formElement!)
        form?.scrapeThreadTags(into: managedObjectContext)
        do {
            try managedObjectContext.save()
        }
        catch {
            fatalError("error saving context after scraping thread tags: \(error)")
        }
        
        return form!
    }

    func testReply() {
        let form = scrapeFormFixtureNamed("newreply")
        XCTAssertTrue(form.threadTags == nil)
        let parameters = form.recommendedParameters()
        XCTAssertEqual((parameters?["action"] as! String), "postreply")
        XCTAssertEqual((parameters?["threadid"] as! String), "3507451")
        XCTAssertEqual((parameters?["formkey"] as! String), "0253d85a945b60daa0165f718df82b8a")
        XCTAssertEqual((parameters?["form_cookie"] as! String), "80c74b48f557")
        XCTAssertTrue((parameters?["message"] as! String).range(of: "terrible") != nil)
        XCTAssertNotNil(parameters?["parseurl"])
        XCTAssertNotNil(parameters?["bookmark"])
        XCTAssert(parameters?["disablesmilies"] == nil)
        XCTAssert(parameters?["signature"] == nil)
    }

    func testReplyWithAmazonSearch() {
        let form = scrapeFormFixtureNamed("newreply-amazon-form")
        XCTAssertNotNil(form.recommendedParameters()?["threadid"])
    }

    func testThread() {
        let form = scrapeFormFixtureNamed("newthread")
        XCTAssertTrue(form.threadTags?.count == 51)
        XCTAssertEqual(fetchAll(ThreadTag.self, inContext: managedObjectContext).count, form.threadTags?.count)
        XCTAssertTrue(form.secondaryThreadTags == nil)
        let parameters = form.allParameters
        XCTAssertNotNil(parameters?["subject"])
        XCTAssertNotNil(parameters?["message"])
        XCTAssertEqual(parameters?["forumid"], "1")
        XCTAssertEqual(parameters?["action"], "postthread")
        XCTAssertEqual(parameters?["formkey"], "0253d85a945b60daa0165f718df82b8a")
        XCTAssertEqual(parameters?["form_cookie"], "e29a15add831")
        XCTAssertEqual(parameters?["parseurl"], "yes")
        XCTAssertEqual(parameters?["bookmark"], "yes")
    }
    
    func testAskTellThread() {
        let form = scrapeFormFixtureNamed("newthread-at")
        XCTAssertTrue(form.threadTags?.count == 55)
        XCTAssertTrue(form.secondaryThreadTags?.count == 2)
        let secondaryTags = fetchAll(ThreadTag.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "imageName IN { 'ama', 'tma' }"))
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags?.count);
    }
    
    func testSAMartThread() {
        let form = scrapeFormFixtureNamed("newthread-samart")
        XCTAssertTrue(form.threadTags?.count == 69)
        XCTAssertTrue(form.secondaryThreadTags?.count == 4)
        let possibleSecondaryTags = fetchAll(ThreadTag.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "imageName LIKE 'icon*ing'"))
        let secondaryTags = possibleSecondaryTags.filter { Int($0.threadTagID!)! < 5 }
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags?.count)
    }
    
    func testMessage() {
        let form = scrapeFormFixtureNamed("private-reply")
        let parameters = form.allParameters
        XCTAssertNotNil(parameters?["message"])
        XCTAssertTrue(parameters?["message"]?.range(of: "InFlames235 wrote") != nil)
    }
}
