//  KeyPath+StringValueTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

class KeyPath_StringValueTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }
    
    func testDodgyUseOfTechnicallyPublicAPI() {
        class Cool: NSObject {
            @objc var prop: String?
        }
        let keyPath = \Cool.prop
        XCTAssertEqual(keyPath.stringValue, "prop")
    }
}
