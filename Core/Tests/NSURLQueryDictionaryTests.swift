//  NSURLQueryDictionaryTests.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import XCTest

final class NSURLQueryDictionaryTests: XCTestCase {
    func testSome() {
        let URL = NSURL(string: "?g=hello&what=updog")!
        XCTAssertEqual(URL.awful_queryDictionary, ["g": "hello", "what": "updog"])
    }
    
    func testOne() {
        let URL = NSURL(string: "?sam=iam")!
        XCTAssertEqual(URL.awful_queryDictionary, ["sam": "iam"])
    }
    
    func testOneSkippingOne() {
        let URL = NSURL(string: "?&howdy=maam")!
        XCTAssertEqual(URL.awful_queryDictionary, ["": "", "howdy": "maam"])
    }
    
    func testEmptyValue() {
        let URL = NSURL(string: "?whodat=")!
        XCTAssertEqual(URL.awful_queryDictionary, ["whodat": ""])
    }
    
    func testEmptyKey() {
        let URL = NSURL(string: "?=ahoy")!
        XCTAssertEqual(URL.awful_queryDictionary, ["": "ahoy"])
    }
    
    func testNoEquals() {
        let URL = NSURL(string: "?hooray")!
        XCTAssertEqual(URL.awful_queryDictionary, ["hooray": ""])
    }
    
    func testManyNoEquals() {
        let URL = NSURL(string: "?reach&for&the&sky")!
        XCTAssertEqual(URL.awful_queryDictionary, ["reach": "", "for": "", "the": "", "sky": ""])
    }
}
