//  PredicateFormatStringTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

class NSPredicate_InterpolatedTests: XCTestCase {

    class Updog: NSObject {
        @objc var prop: String?
    }

    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testKeyPathInConstantValue() {
        let strings = ["yep", "nope"]
        XCTAssertEqual(
            NSPredicate("\(\Updog.prop) IN \(strings)"),
            NSPredicate(format: "%K IN %@", #keyPath(Updog.prop), strings)
        )
    }
}
