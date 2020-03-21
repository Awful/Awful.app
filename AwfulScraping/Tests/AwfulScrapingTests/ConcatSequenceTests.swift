//  ConcatSequenceTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulScraping
import XCTest

class ConcatSequenceTests: XCTestCase {

    func testEmpty() {
        let ints: [Int] = []
        let seq = ConcatSequence([ints])
        XCTAssertEqual(Array(seq), [])
    }

    func testOnce() {
        let ints = [0, 1, 2]
        let seq = ConcatSequence([ints])
        XCTAssertEqual(Array(seq), [0, 1, 2])
    }

    func testTwice() {
        let ints = [0, 1, 2]
        let seq = ConcatSequence([ints, ints])
        XCTAssertEqual(Array(seq), [0, 1, 2, 0, 1, 2])
    }

    func testEmptySandwich() {
        let ints = [0, 1, 2]
        let seq = ConcatSequence([ints, [], ints])
        XCTAssertEqual(Array(seq), [0, 1, 2, 0, 1, 2])
    }
}
