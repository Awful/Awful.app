//  IgnoreListFormTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class IgnoreListFormTests: XCTestCase {
    func testFormAddingFirstIgnoredUser() {
        let scrapedForm = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-empty")
        var form = try! IgnoreListForm(scrapedForm)
        
        XCTAssertEqual(form.initialUsernames, [])
        
        form.usernames = ["v. annoying"]
        
        let formdata = try! form.makeSubmittableForm().submit(button: nil)
        XCTAssertEqual(formdata.entries.filter { $0.name == "listbits[]" }.count, 1)
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "v. annoying" })
    }
    
    func testFormAddingFirstTwoIgnoredUsers() {
        let scrapedForm = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-empty")
        var form = try! IgnoreListForm(scrapedForm)
        
        XCTAssertEqual(form.initialUsernames, [])
        
        form.usernames = ["kinda annoying", "real annoying"]
        
        let formdata = try! form.makeSubmittableForm().submit(button: nil)
        XCTAssertEqual(formdata.entries.filter { $0.name == "listbits[]" }.count, 2)
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "kinda annoying" })
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "real annoying" })
    }
    
    func testFormAddingOneIgnoredUser() {
        let scrapedForm = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-one")
        var form = try! IgnoreListForm(scrapedForm)
        
        XCTAssertEqual(form.initialUsernames, ["carry on then"])
        
        form.usernames += ["persistent whiner"]
        
        let formdata = try! form.makeSubmittableForm().submit(button: nil)
        XCTAssertEqual(formdata.entries.filter { $0.name == "listbits[]" }.count, 2)
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "carry on then" })
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "persistent whiner" })
    }
    
    func testFormAddingTwoIgnoredUsers() {
        let scrapedForm = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-one")
        var form = try! IgnoreListForm(scrapedForm)
        
        XCTAssertEqual(form.initialUsernames, ["carry on then"])
        
        form.usernames += ["persistent whiner", "surprisingly stupid newbie"]
        
        let formdata = try! form.makeSubmittableForm().submit(button: nil)
        XCTAssertEqual(formdata.entries.filter { $0.name == "listbits[]" }.count, 3)
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "carry on then" })
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "persistent whiner" })
        XCTAssertNotNil(formdata.entries.first { $0.name == "listbits[]" && $0.value == "surprisingly stupid newbie" })
    }
    
    func testFormRemovingAllIgnoredUsers() {
        let scrapedForm = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-multiple")
        var form = try! IgnoreListForm(scrapedForm)
        
        XCTAssertEqual(form.initialUsernames.sorted(), ["Diabolik900", "carry on then"])
        
        form.usernames = []
        
        let formdata = try! form.makeSubmittableForm().submit(button: nil)
        XCTAssertEqual(formdata.entries.filter { $0.name == "listbits[]" }.count, 0)
    }
}
