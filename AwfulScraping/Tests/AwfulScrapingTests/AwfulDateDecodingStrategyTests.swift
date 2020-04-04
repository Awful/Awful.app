//  AwfulDateDecodingStrategyTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import  AwfulScraping
import XCTest

class AwfulDateDecodingStrategyTests: XCTestCase {
    func test() {
        struct User: Decodable {
            let regdate: Date
        }
        let json = """
            {"regdate": 1164525312}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss"

        decoder.dateDecodingStrategy = .secondsSince1970
        let surprisinglyWrong = try! decoder.decode(User.self, from: json)
        XCTAssertEqual(formatter.string(from: surprisinglyWrong.regdate), "2006-11-26 07:15:12")

        decoder.dateDecodingStrategy = .awful
        let correct = try! decoder.decode(User.self, from: json)
        XCTAssertEqual(formatter.string(from: correct.regdate), "2006-11-26 01:15:12")
    }
}
