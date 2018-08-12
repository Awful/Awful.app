//  CloseBBcodeTagTests.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest

final class CloseBBcodeTagTests: XCTestCase {
    func testHasOpenCodeTag() {
        XCTAssert(hasOpenCodeTag("[code] [b]"))
        XCTAssertFalse(hasOpenCodeTag("[code] [b] [/code]"))
        XCTAssert(hasOpenCodeTag("[code] [b] [/code][code]"))
        XCTAssert(hasOpenCodeTag("[code=cpp] [b]"))
        XCTAssertFalse(hasOpenCodeTag("[/code]"))
        XCTAssertFalse(hasOpenCodeTag("[codemonkey] [b]"))
        XCTAssert(hasOpenCodeTag("[code][codemonkey]"))
    }

    func testGetCurrentlyOpenTag() {
        XCTAssertEqual(getCurrentlyOpenTag("[b][i]"), "i")
        XCTAssertEqual(getCurrentlyOpenTag("[b][i][/i]"), "b")
        XCTAssertEqual(getCurrentlyOpenTag("[b][/b]"), nil)
        XCTAssertEqual(getCurrentlyOpenTag("[url=foo]"), "url")
        XCTAssertEqual(getCurrentlyOpenTag("[url=foo][b][i][/b]"), "url")
        XCTAssertEqual(getCurrentlyOpenTag("["), nil)
        XCTAssertEqual(getCurrentlyOpenTag("[foo][/x"), "foo")
        XCTAssertEqual(getCurrentlyOpenTag("[foo attr]"), "foo")
        XCTAssertEqual(getCurrentlyOpenTag("[b][code][/code]"), "b")
        XCTAssertEqual(getCurrentlyOpenTag("[list][*]"), "list")
        XCTAssertEqual(getCurrentlyOpenTag("[url="), nil)

        // BBcode would say that "code" is the currently-open tag here…
        // XCTAssertEqual(getCurrentlyOpenTag("[code][b]"), "code")
        // …but we're ok with the auto-close button closing the "b" here as that seems less confusing for the user.
        XCTAssertEqual(getCurrentlyOpenTag("[code][b]"), "b")
    }
}
