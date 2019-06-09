//  ForumHierarchyScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class ForumHierarchyScrapingTests: XCTestCase {
    func testHierarchy() {
        let result = try! scrapeFixture(named: "forumdisplay") as ForumHierarchyScrapeResult

        let groups = result.nodes.filter { (node: ForumHierarchyNode) -> Bool in node.depth == 0 }
        let groupNames = groups
            .map { (group: ForumHierarchyNode) -> String in group.name }
            .sorted()
        XCTAssertEqual(groupNames, ["Archives", "Discussion", "Main", "The Community", "The Finer Arts"])

        let forums = result.nodes.filter { (node: ForumHierarchyNode) -> Bool in node.depth > 0 }
        XCTAssertEqual(forums.count, 66)

        let en = forums.first { (forum: ForumHierarchyNode) -> Bool in forum.name.hasPrefix("E/N") }!
        XCTAssertEqual(en.id.rawValue, "214")
        XCTAssertEqual(en.name, "E/N Bullshit")
        XCTAssertEqual(en.depth, 2)

        let gbs: ForumHierarchyNode = forums[forums.firstIndex(of: en)! - 2]
        XCTAssertEqual(gbs.id.rawValue, "1")
        XCTAssertEqual(gbs.name, "General Bullshit")
        XCTAssertEqual(gbs.depth, en.depth - 1)

        let main = groups[0]
        XCTAssertEqual(main.id.rawValue, "48")
        XCTAssertEqual(main.name, "Main")
        XCTAssertEqual(main.depth, gbs.depth - 1)

        let gameRoom: ForumHierarchyNode = forums.first { $0.id.rawValue == "103"}!
        XCTAssertEqual(gameRoom.name, "The Game Room")
        XCTAssertEqual(gameRoom.depth, 3)

        let traditionalGames: ForumHierarchyNode = forums[forums.firstIndex(of: gameRoom)! - 1]
        XCTAssertEqual(traditionalGames.id.rawValue, "234")
        XCTAssertEqual(traditionalGames.name, "Traditional Games")
        XCTAssertEqual(traditionalGames.depth, gameRoom.depth - 1)

        let games: ForumHierarchyNode = forums[forums.firstIndex(of: traditionalGames)! - 7]
        XCTAssertEqual(games.id.rawValue, "44")
        XCTAssertEqual(games.name, "Games")
        XCTAssertEqual(games.depth, traditionalGames.depth - 1)

        let discussion = groups[1]
        XCTAssertEqual(discussion.id.rawValue, "51")
        XCTAssertEqual(discussion.name, "Discussion")
    }
    
    /// This is a thing that can happen sometimes, and it made the app crash.
    func testDropdownOnlyHasSections() {
        let result = try! scrapeFixture(named: "forumdisplay3") as ForumHierarchyScrapeResult
        let forums = result.nodes.filter { $0.depth > 0 }
        XCTAssert(forums.isEmpty)
    }
}
