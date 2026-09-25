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
        do {
            let json = #"{"things": ["one", 2, {"three": 3}, "four"]}"#.data(using: .utf8)!
            let lossy = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(lossy.things, ["one", "four"], "a malformed element costs only itself")
            XCTAssertEqual(lossy.$things, 2, "skipped elements are counted")
        }
        do {
            let json = #"{"things": [null, "one"]}"#.data(using: .utf8)!
            let lossy = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(lossy.things, ["one"])
        }
        do {
            let json = #"{}"#.data(using: .utf8)!
            let missing = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(missing.things, [])
        }
        do {
            let json = #"{"things": "nope"}"#.data(using: .utf8)!
            let empty = try JSONDecoder().decode(Yep.self, from: json)
            XCTAssertEqual(empty.things, [])
        }
    }

    func testCoerceIntToString() throws {
        struct Yep: Decodable {
            @CoerceIntToString var what: String?
        }

        do {
            let json = #"{"what": "x"}"#.data(using: .utf8)!
            XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: json).what, "x")
        }
        do {
            let json = #"{"what": 5}"#.data(using: .utf8)!
            XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: json).what, "5")
        }
        do {
            let json = #"{"what": null}"#.data(using: .utf8)!
            XCTAssertNil(try JSONDecoder().decode(Yep.self, from: json).what)
        }
        do {
            let json = #"{}"#.data(using: .utf8)!
            XCTAssertNil(try JSONDecoder().decode(Yep.self, from: json).what)
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

    func testDecodingEntitiesAcceptsInt() throws {
        struct Yep: Decodable {
            @DecodingEntities var title: String
        }

        XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: Data(#"{"title": "A &amp; B"}"#.utf8)).title, "A & B")
        XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: Data(#"{"title": 5}"#.utf8)).title, "5")
        XCTAssertThrowsError(try JSONDecoder().decode(Yep.self, from: Data(#"{"title": ["nope"]}"#.utf8)))
    }

    func testIntToBoolMissingKey() throws {
        struct Yep: Decodable {
            @IntToBool var roger: Bool?
        }

        XCTAssertNil(try JSONDecoder().decode(Yep.self, from: Data("{}".utf8)).roger)
    }

    func testBoolOrInt() throws {
        struct Yep: Decodable {
            @BoolOrInt var flag: Bool
        }

        XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: Data(#"{"flag": true}"#.utf8)).flag, true)
        XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: Data(#"{"flag": 0}"#.utf8)).flag, false)
        XCTAssertEqual(try JSONDecoder().decode(Yep.self, from: Data(#"{"flag": 1}"#.utf8)).flag, true)
        XCTAssertThrowsError(try JSONDecoder().decode(Yep.self, from: Data(#"{"flag": "maybe"}"#.utf8)))
    }

    func testLenient() throws {
        struct Yep: Decodable {
            @Lenient var count: Int?
            @Lenient var link: URL?
        }

        let good = try JSONDecoder().decode(Yep.self, from: Data(#"{"count": 3, "link": "https://example.com"}"#.utf8))
        XCTAssertEqual(good.count, 3)
        XCTAssertEqual(good.link, URL(string: "https://example.com"))

        let odd = try JSONDecoder().decode(Yep.self, from: Data(#"{"count": "lots", "link": ""}"#.utf8))
        XCTAssertNil(odd.count)
        XCTAssertNil(odd.link)

        let null = try JSONDecoder().decode(Yep.self, from: Data(#"{"count": null, "link": null}"#.utf8))
        XCTAssertNil(null.count)
        XCTAssertNil(null.link)

        let missing = try JSONDecoder().decode(Yep.self, from: Data("{}".utf8))
        XCTAssertNil(missing.count)
        XCTAssertNil(missing.link)
    }
}
