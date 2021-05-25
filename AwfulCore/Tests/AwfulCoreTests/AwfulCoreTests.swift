//  AwfulCoreTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest

// Can't figure out how to do the NSPrincipalClass trick when running tests as a Swift package, so call `testInit()` from every test I guess.
let testInit: () -> Void = {

    // Set a known time zone for reliable date parsing testing.
    // Hilariously, the SA Forums servers use North American Central Time, but with the Daylight Saving Time rules frozen circa ~2006.
    NSTimeZone.default = TimeZone(identifier: "America/Chicago")!
    
    return {}
}()
