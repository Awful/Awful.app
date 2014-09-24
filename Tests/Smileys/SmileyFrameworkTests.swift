//  SmileyFrameworkTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smileys
import XCTest

class SmileyFrameworkTests: XCTestCase {
    
    func testCreatingKeyboardFrameworkView() {
        let view: KeyboardView? = KeyboardView()
        XCTAssert(view != nil, "Importing worked")
    }
    
}
