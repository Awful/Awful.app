//  PostsPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class PostsPageScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return AwfulPostsPageScraper.self
    }
    
    override func setUp() {
        super.setUp()
        
        NSTimeZone.default = TimeZone(abbreviation: "UTC")!
    }

    func testCanadianPoliticsThread() {
        let scraper = scrapeFixtureNamed("showthread") as! AwfulPostsPageScraper
        let posts = scraper.posts as! [Post]
        XCTAssert(posts.count == 40)
        let allThreads = fetchAll(AwfulThread.self, inContext: managedObjectContext)
        XCTAssert(allThreads.count == 1)
        let canpoliThread = allThreads.first!
        XCTAssert(canpoliThread.threadID == "3507451")
        XCTAssert(canpoliThread.title == "Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe")
        XCTAssertFalse(canpoliThread.closed)
        XCTAssert(fetchAll(Forum.self, inContext: managedObjectContext).count == 1)
        XCTAssert(canpoliThread.forum!.name == "Debate & Discussion")
        let allGroups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        XCTAssert(allGroups.count == 1)
        let group = allGroups[0]
        XCTAssert(group.name == "Discussion")
        
        let firstPost = posts[0]
        XCTAssert(firstPost.postID == "407741839")
        XCTAssert(firstPost.innerHTML!.range(of: "more I think about it") != nil)
        XCTAssert(firstPost.threadIndex == 161)
        XCTAssertEqual(firstPost.postDate!.timeIntervalSince1970, 1348139760)
        XCTAssert(firstPost.beenSeen)
        XCTAssertFalse(firstPost.editable)
        XCTAssert(firstPost.thread == canpoliThread)
        let majuju = firstPost.author!
        XCTAssert(majuju.username == "Majuju")
        XCTAssert(majuju.userID == "108110")
        XCTAssert(majuju.canReceivePrivateMessages)
        XCTAssertEqual(majuju.regdate!.timeIntervalSince1970, 1167350400)
        XCTAssert(majuju.customTitleHTML!.range(of: "AAA") != nil)
        
        let accentAiguPost = posts[10]
        XCTAssert(accentAiguPost.postID == "407751664")
        XCTAssert(accentAiguPost.innerHTML!.range(of: "Québec") != nil)
        
        let opPost = posts[12]
        XCTAssert(opPost.postID == "407751956")
        XCTAssert(opPost.author!.username == "Dreylad")
        XCTAssert(opPost.author! == canpoliThread.author!)
        
        let adminPost = posts[14]
        XCTAssert(adminPost.postID == "407753032")
        XCTAssert(adminPost.author!.username == "angerbot")
        XCTAssert(adminPost.author!.administrator)
        XCTAssertFalse(adminPost.author!.moderator)
        
        let lastPost = posts.last!
        XCTAssert(lastPost.postID == "407769816")
        XCTAssert(lastPost.threadIndex == 200)
        
        XCTAssert(canpoliThread.numberOfPages == 151)
        XCTAssert(canpoliThread.totalReplies >= 6000, "number of replies should reflect number of pages")
    }
    
    func testWeirdSizeTags() {
        // Some posts have a tag that looks like `<size:8>`. Once upon a time, all subsequent posts went missing. In this fixture, Ganker's custom title has a `<size:8>` tag.
        let scraper = scrapeFixtureNamed("showthread2") as! AwfulPostsPageScraper
        let posts = scraper.posts as! [Post]
        XCTAssert(posts.count == 40)
        let ganker = posts[24]
        XCTAssert(ganker.author!.username == "Ganker")
        XCTAssert(ganker.author!.customTitleHTML!.range(of: "forced meme") != nil)
        let brylcreem = posts[25]
        XCTAssert(brylcreem.author!.username == "brylcreem")
    }
    
    func testFYADThreadIndex() {
        let scraper = scrapeFixtureNamed("showthread-fyad") as! AwfulPostsPageScraper
        let posts = scraper.posts as! [Post]
        XCTAssert(posts.count == 10)
        let last = posts.last!
        XCTAssert(last.page == 2)
    }
    
    func testFYADThreadPageOne() {
        let scraper = scrapeFixtureNamed("showthread-fyad2") as! AwfulPostsPageScraper
        let posts = scraper.posts as! [Post]
        XCTAssert(posts.count == 40)
        let first = posts[0]
        XCTAssert(first.author!.username == "BiG TrUcKs !!!")
        XCTAssertEqual(first.postDate!.timeIntervalSince1970, 1388525460)
        XCTAssert(first.innerHTML!.range(of: "twitter assholes") != nil)
        XCTAssert(first.threadIndex ==  1)
        let second = posts[1]
        XCTAssert(second.author!.username == "syxxcowz")
        XCTAssertEqual(second.postDate!.timeIntervalSince1970, 1388525580)
        XCTAssert(second.innerHTML!.range(of: "hate twiter") != nil)
        XCTAssert(second.threadIndex == 2)
    }
    
    func testLastPage() {
        let _ = scrapeFixtureNamed("showthread-last")
        let thread = fetchAll(AwfulThread.self, inContext: managedObjectContext)[0]
        XCTAssert(thread.lastPostAuthorName == "Ashmole")
        XCTAssertEqual(thread.lastPostDate!.timeIntervalSince1970, 1357586460)
    }
    
    func testIgnoredPost() {
        let _ = scrapeFixtureNamed("showthread2")
        let post = fetchOne(Post.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "postID = %@", "428957756"))!
        XCTAssert(post.ignored)
        let others = fetchAll(Post.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "postID != %@", "428957756"))
        XCTAssert(others.count > 0)
        let ignored = (others as NSArray).value(forKeyPath: "@distinctUnionOfObjects.ignored") as! [Bool]
        XCTAssert(ignored.count == 1);
        XCTAssert(ignored[0] == false)
    }
}
