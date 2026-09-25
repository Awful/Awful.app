//  IndexScrapeResultTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulScraping
import XCTest

/// One odd value from the site shouldn't cost the whole forum list.
final class IndexScrapeResultTests: XCTestCase {

    private func decode(_ json: String) throws -> IndexScrapeResult {
        try JSONDecoder().decode(IndexScrapeResult.self, from: Data(json.utf8))
    }

    private func forum(_ id: Int, title: String = "Forum", extra: String = "") -> String {
        #"{"id": \#(id), "title": "\#(title)", "has_threads": true\#(extra)}"#
    }

    private func group(_ id: Int, forums: [String]) -> String {
        #"{"id": \#(id), "title": "Group", "has_threads": false, "sub_forums": [\#(forums.joined(separator: ","))]}"#
    }

    private func index(groups: [String], user: String = #"{"userid": 1, "username": "someone"}"#, stats: String = "null") -> String {
        #"{"user": \#(user), "stats": \#(stats), "forums": [\#(groups.joined(separator: ","))]}"#
    }

    private func forumIDs(_ result: IndexScrapeResult) -> [String] {
        result.allForums.filter { $0.node.hasThreads }.map { $0.node.id }
    }

    func testOddFieldValuesStillDecode() throws {
        let result = try decode(index(
            groups: [group(48, forums: [
                forum(1, extra: #", "description": 5, "title_short": 5, "icon": "", "moderators": [{"userid": 2, "username": 1234}]"#),
                #"{"id": 2, "title": 42, "has_threads": 1}"#,
            ])],
            user: #"{"userid": 1, "username": "someone", "gender": "X", "posts": "lots", "postsperday": "many", "joindate": "a while ago", "lastpost": false, "receivepm": true, "picture": 7, "role": 3}"#,
            stats: #""not stats""#))

        XCTAssertEqual(forumIDs(result), ["1", "2"])
        XCTAssertEqual(result.skippedForumCount, 0)
        XCTAssertEqual(result.forums.first?.subforums.first?.description, "5")
        XCTAssertEqual(result.forums.first?.subforums.first?.moderators.first?.username, "1234")
        XCTAssertEqual(result.forums.first?.subforums.last?.title, "42")
        XCTAssertNil(result.stats)
        XCTAssertNil(result.currentUser.gender)
        XCTAssertNil(result.currentUser.postCount)
    }

    func testMalformedForumIsSkippedAndCounted() throws {
        let result = try decode(index(groups: [
            group(48, forums: [
                forum(1),
                #"{"id": null, "title": "Broken", "has_threads": true}"#,
                forum(3, extra: #", "sub_forums": [\#(forum(4)), {"title": "No ID", "has_threads": true}]"#),
            ]),
        ]))

        XCTAssertEqual(forumIDs(result), ["1", "3", "4"])
        XCTAssertEqual(result.skippedForumCount, 2)
    }

    func testMalformedGroupOnlyCostsItself() throws {
        let result = try decode(index(groups: [
            group(48, forums: [forum(1)]),
            #"{"id": 49, "title": "Broken", "has_threads": "sometimes", "sub_forums": [\#(forum(2))]}"#,
            group(51, forums: [forum(3)]),
        ]))

        XCTAssertEqual(forumIDs(result), ["1", "3"])
        XCTAssertEqual(result.skippedForumCount, 1)
    }

    /// Without a strategy, `JSONDecoder` counts from 2001 and puts these dates 31 years late.
    func testDatesAreUnixTime() throws {
        let result = try IndexScrapeResult(json: Data(index(
            groups: [],
            user: #"{"userid": 1, "username": "someone", "joindate": 1164525312, "lastpost": 1164525312}"#
        ).utf8))

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        XCTAssertEqual(result.currentUser.regdate.map(formatter.string(from:)), "2006-11-26 07:15:12")
        XCTAssertEqual(result.currentUser.lastPostDate.map(formatter.string(from:)), "2006-11-26 07:15:12")
    }
}
