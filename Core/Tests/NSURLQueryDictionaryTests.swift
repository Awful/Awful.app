//  NSURLQueryDictionaryTests.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import XCTest

final class NSURLQueryDictionaryTests: XCTestCase {
    func testSome() {
        let url = URL(string: "?g=hello&what=updog")!
        XCTAssertEqual(url.awful_queryDictionary, ["g": "hello", "what": "updog"])
    }
    
    func testOne() {
        let url = URL(string: "?sam=iam")!
        XCTAssertEqual(url.awful_queryDictionary, ["sam": "iam"])
    }
    
    func testOneSkippingOne() {
        let url = URL(string: "?&howdy=maam")!
        XCTAssertEqual(url.awful_queryDictionary, ["": "", "howdy": "maam"])
    }
    
    func testEmptyValue() {
        let url = URL(string: "?whodat=")!
        XCTAssertEqual(url.awful_queryDictionary, ["whodat": ""])
    }
    
    func testEmptyKey() {
        let url = URL(string: "?=ahoy")!
        XCTAssertEqual(url.awful_queryDictionary, ["": "ahoy"])
    }
    
    func testNoEquals() {
        let url = URL(string: "?hooray")!
        XCTAssertEqual(url.awful_queryDictionary, ["hooray": ""])
    }
    
    func testManyNoEquals() {
        let url = URL(string: "?reach&for&the&sky")!
        XCTAssertEqual(url.awful_queryDictionary, ["reach": "", "for": "", "the": "", "sky": ""])
    }
}
