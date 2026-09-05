//  ServerErrorTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class ServerErrorTests: XCTestCase {

    func testHTTPStatusNamesTheCode() {
        let error = ServerError.httpStatus(code: 522, cloudflareRayID: nil)
        XCTAssertTrue(error.localizedDescription.contains("522"))
        XCTAssertFalse(error.localizedDescription.contains("Ray ID"))
    }

    func testHTTPStatusIncludesRayIDWhenPresent() {
        let error = ServerError.httpStatus(code: 502, cloudflareRayID: "8f1e2d3c4b5a6978-LHR")
        XCTAssertTrue(error.localizedDescription.contains("502"))
        XCTAssertTrue(error.localizedDescription.contains("8f1e2d3c4b5a6978-LHR"))
    }
}
