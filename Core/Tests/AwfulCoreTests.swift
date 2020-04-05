//  AwfulCoreTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest

/// The principal class of AwfulCore's test bundle (as set in its Info.plist).
@objc(AwfulCoreTests)
class AwfulCoreTests: NSObject {

    override init() {
        super.init()
        
        XCTestObservationCenter.shared.addTestObserver(self)
    }
}

extension AwfulCoreTests: XCTestObservation {
    func testBundleWillStart(_ testBundle: Bundle) {

        // Set a known time zone for reliable date parsing testing.
        // Hilariously, the SA Forums servers use North American Central Time, but with the Daylight Saving Time rules frozen circa ~2006.
        NSTimeZone.default = TimeZone(identifier: "America/Chicago")!
    }
}
