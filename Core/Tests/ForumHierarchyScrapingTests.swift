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
        let _ = scrapeFixtureNamed(fixtureName: "forumdisplay") as! AwfulForumHierarchyScraper
        let groups = fetchAll(type: ForumGroup.self, inContext: managedObjectContext)
        let groupNames = groups.map{$0.name!}.sorted()
        XCTAssertEqual(groupNames, ["Archives", "Discussion", "Main", "The Community", "The Finer Arts"])
        XCTAssertTrue(fetchAll(type: Forum.self, inContext: managedObjectContext).count == 66)
        
        let EN = fetchOne(type: Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "name BEGINSWITH 'E/N'"))!
        XCTAssert(EN.forumID == "214")
        XCTAssert(EN.name == "E/N Bullshit")
        let GBS = EN.parentForum!
        XCTAssert(GBS.forumID == "1")
        XCTAssert(GBS.name == "General Bullshit")
        let main = GBS.group!
        XCTAssert(main.groupID == "48")
        XCTAssert(main.name == "Main")
        XCTAssert(EN.group == main)
        
        let gameRoom = fetchOne(type: Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '103'"))!
        XCTAssert(gameRoom.name == "The Game Room")
        let traditionalGames = gameRoom.parentForum!
        XCTAssert(traditionalGames.forumID == "234")
        XCTAssert(traditionalGames.name == "Traditional Games")
        let games = traditionalGames.parentForum!
        XCTAssert(games.forumID == "44")
        XCTAssert(games.name == "Games")
        let discussion = games.group!
        XCTAssert(discussion.groupID == "51")
        XCTAssert(discussion.name == "Discussion")
        XCTAssert(traditionalGames.group == discussion)
        XCTAssert(gameRoom.group == discussion)
    }
    
    /// This is a thing that can happen sometimes, and it made the app crash.
    func testDropdownOnlyHasSections() {
        let document = fixtureNamed(basename: "forumdisplay3")
        let scraper = AwfulForumHierarchyScraper.scrape(document, into: managedObjectContext)
        XCTAssert(scraper?.error != nil)
    }
}
