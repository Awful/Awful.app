//  IgnoreListScrapingTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class IgnoreListScrapingTests: XCTestCase {
    func testEmpty() {
        let form = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-empty")
        XCTAssertEqual(form.textboxes.map { $0.name }, ["listbits[]", "listbits[]"])
        XCTAssertEqual(form.textboxes.map { $0.value }, ["", ""])
    }
    
    func testMultiple() {
        let form = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-multiple")
        XCTAssertEqual(form.textboxes.count, 4)
        
        let filled = form.textboxes.filter { !$0.value.isEmpty }
        XCTAssertEqual(filled.map { $0.value }, ["Diabolik900", "carry on then"])
    }
    
    func testOne() {
        let form = try! scrapeForm(matchingSelector: "form[action = 'member2.php']", inFixtureNamed: "ignore-one")
        XCTAssertEqual(form.textboxes.count, 3)
        
        let filled = form.textboxes.filter { !$0.value.isEmpty }
        XCTAssertEqual(filled.map { $0.value }, ["carry on then"])
    }
    
    func testErrorAddingStaff() {
        let result = try! scrapeFixture(named: "ignore-staff") as IgnoreListChangeScrapeResult
        guard case .failure(error: _, rejectedUsername: let username?) = result else {
            return XCTFail("expected rejected username")
        }
        
        XCTAssertEqual(username, "Lowtax")
    }
    
    func testSuccess() {
        let result = try! scrapeFixture(named: "ignore-success") as IgnoreListChangeScrapeResult
        switch result {
        case .success:
            break // test passes
            
        case .failure, .unknown:
            XCTFail("expected success")
        }
    }
}
