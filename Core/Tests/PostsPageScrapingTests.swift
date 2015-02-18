//  PostsPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class PostsPageScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return AwfulPostsPageScraper.self
    }
    
    func testCanadianPoliticsThread() {
        let scraper = scrapeFixtureNamed("showthread") as AwfulPostsPageScraper
        let posts = scraper.posts as [Post]
        XCTAssertTrue(posts.count == 40)
        let allThreads = fetchAll(Thread.self, inContext: managedObjectContext)
        XCTAssertTrue(allThreads.count == 1)
        let canpoliThread = allThreads.first!
        XCTAssertEqual(canpoliThread.threadID, "3507451")
        XCTAssertEqual(canpoliThread.title!, "Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe")
        XCTAssertFalse(canpoliThread.closed)
        XCTAssertTrue(fetchAll(Forum.self, inContext: managedObjectContext).count == 1)
        XCTAssertEqual(canpoliThread.forum!.name!, "Debate & Discussion")
        let allGroups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        XCTAssertTrue(allGroups.count == 1)
        let group = allGroups[0]
        XCTAssertEqual(group.name!, "Discussion")
        
        let firstPost = posts[0]
        XCTAssertEqual(firstPost.postID, "407741839")
        XCTAssertTrue(firstPost.innerHTML!.rangeOfString("more I think about it") != nil)
        XCTAssertTrue(firstPost.threadIndex == 161)
        XCTAssertEqual(firstPost.postDate!.timeIntervalSince1970, 1348139760)
        XCTAssertTrue(firstPost.beenSeen)
        XCTAssertFalse(firstPost.editable)
        XCTAssertEqual(firstPost.thread!, canpoliThread)
        let majuju = firstPost.author!
        XCTAssertEqual(majuju.username!, "Majuju")
        XCTAssertEqual(majuju.userID, "108110")
        XCTAssertTrue(majuju.canReceivePrivateMessages);
        XCTAssertEqual(majuju.regdate!.timeIntervalSince1970, 1167350400)
        XCTAssertTrue(majuju.customTitleHTML!.rangeOfString("AAA") != nil)
        
        let accentAiguPost = posts[10]
        XCTAssertEqual(accentAiguPost.postID, "407751664")
        XCTAssertTrue(accentAiguPost.innerHTML!.rangeOfString("Québec") != nil)
        
        let opPost = posts[12]
        XCTAssertEqual(opPost.postID, "407751956")
        XCTAssertEqual(opPost.author!.username!, "Dreylad")
        XCTAssertEqual(opPost.author!, canpoliThread.author!)
        
        let adminPost = posts[14]
        XCTAssertEqual(adminPost.postID, "407753032")
        XCTAssertEqual(adminPost.author!.username!, "angerbot")
        XCTAssertTrue(adminPost.author!.administrator)
        XCTAssertFalse(adminPost.author!.moderator)
        
        let lastPost = posts.last!
        XCTAssertEqual(lastPost.postID, "407769816")
        XCTAssertTrue(lastPost.threadIndex == 200)
        
        XCTAssertTrue(canpoliThread.numberOfPages == 151)
        XCTAssertTrue(canpoliThread.totalReplies >= 6000, "number of replies should reflect number of pages")
    }
    
    func testWeirdSizeTags() {
        // Some posts have a tag that looks like `<size:8>`. Once upon a time, all subsequent posts went missing. In this fixture, Ganker's custom title has a `<size:8>` tag.
        let scraper = scrapeFixtureNamed("showthread2") as AwfulPostsPageScraper
        let posts = scraper.posts as [Post]
        XCTAssertTrue(posts.count == 40)
        let ganker = posts[24]
        XCTAssertEqual(ganker.author!.username!, "Ganker")
        XCTAssertTrue(ganker.author!.customTitleHTML!.rangeOfString("forced meme") != nil)
        let brylcreem = posts[25]
        XCTAssertEqual(brylcreem.author!.username!, "brylcreem")
    }
    
    func testFYADThreadIndex() {
        let scraper = scrapeFixtureNamed("showthread-fyad") as AwfulPostsPageScraper
        let posts = scraper.posts as [Post]
        XCTAssertTrue(posts.count == 10)
        let last = posts.last!
        XCTAssertTrue(last.page == 2)
    }
    
    func testFYADThreadPageOne() {
        let scraper = scrapeFixtureNamed("showthread-fyad2") as AwfulPostsPageScraper
        let posts = scraper.posts as [Post]
        XCTAssertTrue(posts.count == 40)
        let first = posts[0]
        XCTAssertEqual(first.author!.username!, "BiG TrUcKs !!!")
        XCTAssertEqual(first.postDate!.timeIntervalSince1970, 1388525460)
        XCTAssertTrue(first.innerHTML!.rangeOfString("twitter assholes") != nil)
        XCTAssertTrue(first.threadIndex ==  1)
        let second = posts[1]
        XCTAssertEqual(second.author!.username!, "syxxcowz")
        XCTAssertEqual(second.postDate!.timeIntervalSince1970, 1388525580)
        XCTAssertTrue(second.innerHTML!.rangeOfString("hate twiter") != nil)
        XCTAssertTrue(second.threadIndex == 2)
    }
    
    func testLastPage() {
        scrapeFixtureNamed("showthread-last")
        let thread = fetchAll(Thread.self, inContext: managedObjectContext)[0]
        XCTAssertEqual(thread.lastPostAuthorName!, "Ashmole")
        XCTAssertEqual(thread.lastPostDate!.timeIntervalSince1970, 1357586460)
    }
    
    func testIgnoredPost() {
        scrapeFixtureNamed("showthread2")
        let post = fetchOne(Post.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "postID = %@", "428957756"))!
        XCTAssertTrue(post.ignored)
        let others = fetchAll(Post.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "postID != %@", "428957756"))
        XCTAssertTrue(others.count > 0)
        let ignored = (others as NSArray).valueForKeyPath("@distinctUnionOfObjects.ignored") as [Bool]
        XCTAssertTrue(ignored.count == 1);
        XCTAssertEqual(ignored[0], false)
    }
}
