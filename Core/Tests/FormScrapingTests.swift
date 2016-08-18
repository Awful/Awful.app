//  FormScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class FormScrapingTests: ScrapingTestCase {
    private func scrapeFormFixtureNamed(fixtureName: String) -> AwfulForm {
        let document = fixtureNamed(basename: fixtureName)
        let formElement = document.firstNode(matchingSelector: "form[name='vbform']")
        let form = AwfulForm(element: formElement)
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
        let form = scrapeFormFixtureNamed(fixtureName: "newreply")
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
        let form = scrapeFormFixtureNamed(fixtureName: "newreply-amazon-form")
        XCTAssertNotNil(form.recommendedParameters()["threadid"])
    }

    func testThread() {
        let form = scrapeFormFixtureNamed(fixtureName: "newthread")
        XCTAssertTrue(form.threadTags.count == 51)
        XCTAssertEqual(fetchAll(type: ThreadTag.self, inContext: managedObjectContext).count, form.threadTags.count)
        XCTAssertTrue(form.secondaryThreadTags == nil)
        let parameters = form.allParameters
        XCTAssertNotNil(parameters?["subject"])
        XCTAssertNotNil(parameters?["message"])
        XCTAssertEqual((parameters?["forumid"] as! String), "1")
        XCTAssertEqual((parameters?["action"] as! String), "postthread")
        XCTAssertEqual((parameters?["formkey"] as! String), "0253d85a945b60daa0165f718df82b8a")
        XCTAssertEqual((parameters?["form_cookie"] as! String), "e29a15add831")
        XCTAssertEqual((parameters?["parseurl"] as! String), "yes")
        XCTAssertEqual((parameters?["bookmark"] as! String), "yes")
    }
    
    func testAskTellThread() {
        let form = scrapeFormFixtureNamed(fixtureName: "newthread-at")
        XCTAssertTrue(form.threadTags.count == 55)
        XCTAssertTrue(form.secondaryThreadTags.count == 2)
        let secondaryTags = fetchAll(type: ThreadTag.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "imageName IN { 'ama', 'tma' }"))
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count);
    }
    
    func testSAMartThread() {
        let form = scrapeFormFixtureNamed(fixtureName: "newthread-samart")
        XCTAssertTrue(form.threadTags.count == 69)
        XCTAssertTrue(form.secondaryThreadTags.count == 4)
        let possibleSecondaryTags = fetchAll(type: ThreadTag.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "imageName LIKE 'icon*ing'"))
        let secondaryTags = possibleSecondaryTags.filter { Int($0.threadTagID!)! < 5 }
        XCTAssertEqual(secondaryTags.count, form.secondaryThreadTags.count)
    }
    
    func testMessage() {
        let form = scrapeFormFixtureNamed(fixtureName: "private-reply")
        let parameters = form.allParameters
        XCTAssertNotNil(parameters?["message"])
        XCTAssertTrue((parameters?["message"] as! String).range(of: "InFlames235 wrote") != nil)
    }
}
