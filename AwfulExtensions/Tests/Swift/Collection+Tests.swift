//  Collection+Tests.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulExtensions
import XCTest

final class Collection_Tests: XCTestCase {
    func testScan() {
        var scanner = "ahoy"[...]
        XCTAssertFalse(scanner.scan("n"))
        XCTAssertFalse(scanner.scan("nope"))
        XCTAssertFalse(scanner.scan("nopenopenope"))
        XCTAssertTrue(scanner.scan(""))
        XCTAssertTrue(scanner.scan("ah"))
        XCTAssertFalse(scanner.scan("no"))
        XCTAssertTrue(scanner.scan("oy"))
        XCTAssertTrue(scanner.scan(""))
        XCTAssertFalse(scanner.scan("nope"))
    }

    func testScanUntil() {
        var scanner = "test123"[...]
        XCTAssertNil(scanner.scan(until: \.isLetter))
        XCTAssertEqual(scanner.scan(until: \.isNumber), "test")
        XCTAssertNil(scanner.scan(until: \.isNumber))
        XCTAssertEqual(scanner.scan(until: \.isLetter), "123")
        XCTAssertNil(scanner.scan(until: { _ in false }))
    }

    func testScanWhile() {
        var scanner = "bye98"[...]
        XCTAssertNil(scanner.scan(while: \.isNumber))
        XCTAssertEqual(scanner.scan(while: \.isLetter), "bye")
        XCTAssertNil(scanner.scan(while: \.isLetter))
        XCTAssertEqual(scanner.scan(while: \.isNumber), "98")
        XCTAssertNil(scanner.scan(while: { _ in true }))
    }
}
