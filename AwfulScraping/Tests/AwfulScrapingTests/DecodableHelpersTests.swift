//  DecodableHelpersTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulScraping
import XCTest

class DecodableHelpersTests: XCTestCase {
    func testDefaultEmpty() throws {
        struct Yep: Decodable {
            @DefaultEmpty var things: [String]
        }

        do {
            let json = #"{"things": null}"#.data(using: .utf8)!
            let empty = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(empty.things, [])
        }
        do {
            let json = #"{"things": []}"#.data(using: .utf8)!
            let empty = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(empty.things, [])
        }
        do {
            let json = #"{"things": ["one"]}"#.data(using: .utf8)!
            let present = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(present.things, ["one"])
        }
    }

    func testEmptyStringNil() throws {
        struct Yep: Decodable {
            @EmptyStringNil var holla: String?
        }

        do {
            let json = #"{"holla": null}"#.data(using: .utf8)!
            let null = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertNil(null.holla)
        }
        do {
            let json = #"{"holla": ""}"#.data(using: .utf8)!
            let null = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertNil(null.holla)
        }
        do {
            let json = #"{"holla": "boi"}"#.data(using: .utf8)!
            let present = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(present.holla, "boi")
        }
    }

    func testIntToBool() throws {
        struct Yep: Decodable {
            @IntToBool var roger: Bool?
        }

        do {
            let json = #"{"roger": null}"#.data(using: .utf8)!
            let null = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertNil(null.roger)
        }
        do {
            let json = #"{"roger": 0}"#.data(using: .utf8)!
            let no = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(no.roger, false)
        }
        do {
            let json = #"{"roger": 1}"#.data(using: .utf8)!
            let yes = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(yes.roger, true)
        }
    }

    func testIntOrString() throws {
        struct Yep: Decodable {
            @IntOrString var id: String
        }

        do {
            let json = #"{"id": 1}"#.data(using: .utf8)!
            let one = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(one.id, "1")
        }
        do {
            let json = #"{"id": "1"}"#.data(using: .utf8)!
            let one = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(one.id, "1")
        }
    }
}
