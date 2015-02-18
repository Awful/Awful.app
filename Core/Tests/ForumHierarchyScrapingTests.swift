//  ForumHierarchyScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class ForumHierarchyScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return AwfulForumHierarchyScraper.self
    }
    
    func testHierarchy() {
        let scraper = scrapeFixtureNamed("forumdisplay") as AwfulForumHierarchyScraper
        let groups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        let groupNames = groups.map{$0.name!}.sorted(<)
        XCTAssertEqual(groupNames, ["Archives", "Discussion", "Main", "The Community", "The Finer Arts"])
        XCTAssertTrue(fetchAll(Forum.self, inContext: managedObjectContext).count == 66)
        
        let EN = fetchOne(Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "name BEGINSWITH 'E/N'"))!
        XCTAssertEqual(EN.forumID, "214")
        XCTAssertEqual(EN.name!, "E/N Bullshit")
        let GBS = EN.parentForum!
        XCTAssertEqual(GBS.forumID, "1")
        XCTAssertEqual(GBS.name!, "General Bullshit")
        let main = GBS.group!
        XCTAssertEqual(main.groupID, "48")
        XCTAssertEqual(main.name!, "Main")
        XCTAssertEqual(EN.group!, main)
        
        let gameRoom = fetchOne(Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '103'"))!
        XCTAssertEqual(gameRoom.name!, "The Game Room")
        let traditionalGames = gameRoom.parentForum!
        XCTAssertEqual(traditionalGames.forumID, "234")
        XCTAssertEqual(traditionalGames.name!, "Traditional Games")
        let games = traditionalGames.parentForum!
        XCTAssertEqual(games.forumID, "44")
        XCTAssertEqual(games.name!, "Games")
        let discussion = games.group!
        XCTAssertEqual(discussion.groupID, "51")
        XCTAssertEqual(discussion.name!, "Discussion")
        XCTAssertEqual(traditionalGames.group!, discussion)
        XCTAssertEqual(gameRoom.group!, discussion)
    }
}
