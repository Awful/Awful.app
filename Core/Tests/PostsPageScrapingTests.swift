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
        XCTAssertEqual(scraper.posts?.count, 40)
        let allThreads = fetchAll(AwfulThread.self, inContext: managedObjectContext)
        XCTAssertEqual(allThreads.count, 1)
        let canpolThread = allThreads.first
        XCTAssertEqual(canpolThread?.threadID, "3507451")
        XCTAssertEqual(canpolThread?.title, "Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe")
        XCTAssertEqual(canpolThread?.closed, false)
        XCTAssertEqual(fetchAll(Forum.self, inContext: managedObjectContext).count, 1)
        XCTAssertEqual(canpolThread?.forum?.name, "Debate & Discussion")
        let allGroups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        XCTAssertEqual(allGroups.count, 1)
        let group = allGroups[0]
        XCTAssertEqual(group.name, "Discussion")
        
        let firstPost = scraper.posts?[0]
        XCTAssertEqual(firstPost?.postID, "407741839")
        XCTAssertNotNil(firstPost?.innerHTML?.range(of: "more I think about it"))
        XCTAssertEqual(firstPost?.threadIndex, 161)
        XCTAssertEqual(firstPost?.postDate?.timeIntervalSince1970, 1348139760)
        XCTAssertEqual(firstPost?.beenSeen, true)
        XCTAssertEqual(firstPost?.editable, false)
        XCTAssertEqual(firstPost?.thread, canpolThread)
        let majuju = firstPost?.author
        XCTAssertEqual(majuju?.username, "Majuju")
        XCTAssertEqual(majuju?.userID, "108110")
        XCTAssertEqual(majuju?.canReceivePrivateMessages, true)
        XCTAssertEqual(majuju?.regdate?.timeIntervalSince1970, 1167350400)
        XCTAssertNotNil(majuju?.customTitleHTML?.range(of: "AAA"))
        
        let accentAiguPost = scraper.posts?[10]
        XCTAssertEqual(accentAiguPost?.postID, "407751664")
        XCTAssertNotNil(accentAiguPost?.innerHTML?.range(of: "Québec"))
        
        let opPost = scraper.posts?[12]
        XCTAssert(opPost?.postID == "407751956")
        XCTAssert(opPost?.author?.username == "Dreylad")
        XCTAssertEqual(opPost?.author, canpolThread?.author)
        
        let adminPost = scraper.posts?[14]
        XCTAssertEqual(adminPost?.postID, "407753032")
        XCTAssertEqual(adminPost?.author?.username, "angerbot")
        XCTAssertEqual(adminPost?.author?.administrator, true)
        XCTAssertEqual(adminPost?.author?.moderator, false)
        
        let lastPost = scraper.posts?.last
        XCTAssertEqual(lastPost?.postID, "407769816")
        XCTAssertEqual(lastPost?.threadIndex, 200)
        
        XCTAssertEqual(canpolThread?.numberOfPages, 151)
        XCTAssert((canpolThread?.totalReplies ?? 0) >= 6000, "number of replies should reflect number of pages")
    }
    
    func testWeirdSizeTags() {
        // Some posts have a tag that looks like `<size:8>`. Once upon a time, all subsequent posts went missing. In this fixture, Ganker's custom title has a `<size:8>` tag.
        let scraper = scrapeFixtureNamed("showthread2") as! AwfulPostsPageScraper
        XCTAssertEqual(scraper.posts?.count, 40)
        let ganker = scraper.posts?[24]
        XCTAssertEqual(ganker?.author?.username, "Ganker")
        XCTAssertNotNil(ganker?.author?.customTitleHTML?.range(of: "forced meme"))
        let brylcreem = scraper.posts?[25]
        XCTAssertEqual(brylcreem?.author?.username, "brylcreem")
    }
    
    func testFYADThreadIndex() {
        let scraper = scrapeFixtureNamed("showthread-fyad") as! AwfulPostsPageScraper
        XCTAssertEqual(scraper.posts?.count, 10)
        let last = scraper.posts?.last
        XCTAssertEqual(last?.page, 2)
    }
    
    func testFYADThreadPageOne() {
        let scraper = scrapeFixtureNamed("showthread-fyad2") as! AwfulPostsPageScraper
        XCTAssertEqual(scraper.posts?.count, 40)
        let first = scraper.posts?[0]
        XCTAssertEqual(first?.author?.username, "BiG TrUcKs !!!")
        XCTAssertEqual(first?.postDate?.timeIntervalSince1970, 1388525460)
        XCTAssertNotNil(first?.innerHTML?.range(of: "twitter assholes"))
        XCTAssertEqual(first?.threadIndex,  1)
        let second = scraper.posts?[1]
        XCTAssertEqual(second?.author?.username, "syxxcowz")
        XCTAssertEqual(second?.postDate?.timeIntervalSince1970, 1388525580)
        XCTAssertNotNil(second?.innerHTML?.range(of: "hate twiter"))
        XCTAssertEqual(second?.threadIndex, 2)
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
