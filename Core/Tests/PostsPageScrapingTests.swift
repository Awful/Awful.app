//  PostsPageScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PostsPageScrapingTests: XCTestCase {
    override class func setUp() {
        super.setUp()

        makeUTCDefaultTimeZone()
    }
    
    func testCanadianPoliticsThread() {
        let result = try! scrapeFixture(named: "showthread") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.count, 40)

        XCTAssertEqual(result.threadID?.rawValue, "3507451")
        XCTAssertEqual(result.threadTitle, "Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe")
        XCTAssertFalse(result.threadIsClosed)

        XCTAssertEqual(result.breadcrumbs?.forums.last?.name, "Debate & Discussion")
        XCTAssertEqual(result.breadcrumbs?.forums.first?.name, "Discussion")
        
        let firstPost = result.posts[0]
        XCTAssertEqual(firstPost.id.rawValue, "407741839")
        XCTAssert(firstPost.authorCanReceivePrivateMessages)
        XCTAssert(firstPost.body.contains("more I think about it"))
        XCTAssertEqual(firstPost.indexInThread, 161)
        XCTAssertEqual(firstPost.postDate?.timeIntervalSince1970, 1348139760)
        XCTAssert(firstPost.hasBeenSeen)
        XCTAssertFalse(firstPost.isEditable)

        let majuju = firstPost.author
        XCTAssertEqual(majuju.username, "Majuju")
        XCTAssertEqual(majuju.userID.rawValue, "108110")
        XCTAssertEqual(majuju.regdate?.timeIntervalSince1970, 1167350400)
        XCTAssert(majuju.customTitle.contains("AAA"))
        
        let accentAiguPost = result.posts[10]
        XCTAssertEqual(accentAiguPost.id.rawValue, "407751664")
        XCTAssert(accentAiguPost.body.contains("Québec"))
        
        let opPost = result.posts[12]
        XCTAssertEqual(opPost.id.rawValue, "407751956")
        XCTAssertEqual(opPost.author.username, "Dreylad")
        XCTAssert(opPost.authorIsOriginalPoster)
        
        let adminPost = result.posts[14]
        XCTAssertEqual(adminPost.id.rawValue, "407753032")
        XCTAssertEqual(adminPost.author.username, "angerbot")
        XCTAssert(adminPost.author.isAdministrator)
        XCTAssertFalse(adminPost.author.isModerator)
        
        let lastPost = result.posts.last
        XCTAssertEqual(lastPost?.id.rawValue, "407769816")
        XCTAssertEqual(lastPost?.indexInThread, 200)
        
        XCTAssertEqual(result.pageCount, 151)
    }
    
    func testWeirdSizeTags() {
        // Some posts have a tag that looks like `<size:8>`. Once upon a time, all subsequent posts went missing. In this fixture, Ganker's custom title has a `<size:8>` tag.
        let result = try! scrapeFixture(named: "showthread2") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.count, 40)
        let ganker = result.posts[24]
        XCTAssertEqual(ganker.author.username, "Ganker")
        XCTAssertEqual(ganker.author.customTitle.contains("forced meme"), true)
        let brylcreem = result.posts[25]
        XCTAssertEqual(brylcreem.author.username, "brylcreem")
    }
    
    func testFYADThreadIndex() {
        let result = try! scrapeFixture(named: "showthread-fyad") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.count, 10)
        XCTAssertEqual(result.pageNumber, 2)
    }
    
    func testFYADThreadPageOne() {
        let result = try! scrapeFixture(named: "showthread-fyad2") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.count, 40)

        let first = result.posts[0]
        XCTAssertEqual(first.author.username, "BiG TrUcKs !!!")
        XCTAssertEqual(first.postDate?.timeIntervalSince1970, 1388525460)
        XCTAssert(first.body.contains("twitter assholes"))
        XCTAssertNil(first.indexInThread)

        let second = result.posts[1]
        XCTAssertEqual(second.author.username, "syxxcowz")
        XCTAssertEqual(second.postDate?.timeIntervalSince1970, 1388525580)
        XCTAssert(second.body.contains("hate twiter"))
        XCTAssertNil(second.indexInThread)
    }
    
    func testLastPage() {
        let result = try! scrapeFixture(named: "showthread-last") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.last?.author.username, "Ashmole")
        XCTAssertEqual(result.posts.last?.postDate?.timeIntervalSince1970, 1357586460)
    }
    
    func testIgnoredPost() {
        let result = try! scrapeFixture(named: "showthread2") as PostsPageScrapeResult
        XCTAssertEqual(result.posts.count, 40)

        let ignored = result.posts.filter { $0.isIgnored }
        XCTAssertEqual(ignored.count, 1)

        let post = ignored[0]
        XCTAssertEqual(post.id.rawValue, "428957756")
    }

    func testOneUserOnepage() {
        let result = try! scrapeFixture(named: "showthread-oneuser") as PostsPageScrapeResult
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.pageNumber, 1)
    }
}
