//  FormScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class FormScrapingTests: ScrapingTestCase {

    private func scrapeFormFixtureNamed(fixtureName: String) -> AwfulForm {
        let document = loadFixtureNamed(fixtureName)
        let formElement = document.firstNodeMatchingSelector("form[name='vbform']")
        let form = AwfulForm(element: formElement)
        form.scrapeThreadTagsIntoManagedObjectContext(managedObjectContext)
        var error: NSError?
        let ok = managedObjectContext.save(&error)
        assert(ok, "error saving context after scraping thread tags: \(error!)")
        return form
    }

    func testReply() {
        let form = scrapeFormFixtureNamed("newreply")
        XCTAssertTrue(form.threadTags == nil)
        let parameters = form.recommendedParameters()
        XCTAssertEqual(parameters["action"] as String, "postreply")
        XCTAssertEqual(parameters["threadid"] as String, "3507451")
        XCTAssertEqual(parameters["formkey"] as String, "0253d85a945b60daa0165f718df82b8a")
        XCTAssertEqual(parameters["form_cookie"] as String, "80c74b48f557")
        XCTAssertTrue((parameters["message"] as String).rangeOfString("terrible") != nil)
        XCTAssertNotNil(parameters["parseurl"])
        XCTAssertNotNil(parameters["bookmark"])
        XCTAssertNil(parameters["disablesmilies"])
        XCTAssertNil(parameters["signature"])
    }

    func testReplyWithAmazonSearch() {
        let form = scrapeFormFixtureNamed("newreply-amazon-form")
        XCTAssertNotNil(form.recommendedParameters()["threadid"])
    }

    func testThread() {
        let form = scrapeFormFixtureNamed("newthread")
        XCTAssertTrue(form.threadTags.count == 51)
        XCTAssertEqual(ThreadTag.numberOfObjectsInManagedObjectContext(managedObjectContext), form.threadTags.count)
        XCTAssertTrue(form.secondaryThreadTags == nil)
        let parameters = form.allParameters
        XCTAssertNotNil(parameters["subject"])
        XCTAssertNotNil(parameters["message"])
        XCTAssertEqual(parameters["forumid"] as String, "1")
        XCTAssertEqual(parameters["action"] as String, "postthread")
        XCTAssertEqual(parameters["formkey"] as String, "0253d85a945b60daa0165f718df82b8a")
        XCTAssertEqual(parameters["form_cookie"] as String, "e29a15add831")
        XCTAssertEqual(parameters["parseurl"] as String, "yes")
        XCTAssertEqual(parameters["bookmark"] as String, "yes")
    }
    
    func testAskTellThread() {
        let form = scrapeFormFixtureNamed("newthread-at")
        XCTAssertTrue(form.threadTags.count == 55)
        XCTAssertTrue(form.secondaryThreadTags.count == 2)
        let secondaryTags = ThreadTag.fetchAllInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "imageName IN { 'ama', 'tma' }"))
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count);
    }
    
    func testSAMartThread() {
        let form = scrapeFormFixtureNamed("newthread-samart")
        XCTAssertTrue(form.threadTags.count == 69)
        XCTAssertTrue(form.secondaryThreadTags.count == 4)
        let possibleSecondaryTags = ThreadTag.fetchAllInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "imageName LIKE 'icon*ing'")) as [ThreadTag]
        let secondaryTags = possibleSecondaryTags.filter { $0.threadTagID!.toInt()! < 5 }
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count)
    }
    
    func testMessage() {
        let form = scrapeFormFixtureNamed("private-reply")
        let parameters = form.allParameters
        XCTAssertNotNil(parameters["message"])
        XCTAssertTrue((parameters["message"] as String).rangeOfString("InFlames235 wrote") != nil)
    }
}
