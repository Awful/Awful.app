//  ProfileScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class ProfileScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }
    
    func testWithAvatarAndText() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile")
        XCTAssertEqual(scraped.author.userID, UserID(rawValue: "106125"))
        XCTAssertEqual(scraped.author.username, "pokeyman")
        XCTAssert(scraped.author.customTitle.contains("play?"))
        XCTAssert(scraped.author.customTitle.contains("title-pokeyman"))
        XCTAssert(scraped.canReceivePrivateMessages)
        XCTAssertEqual(scraped.icqName, "1234")
        XCTAssert(scraped.aimName.isEmpty)
        XCTAssert(scraped.yahooName.isEmpty)
        XCTAssert(scraped.location.isEmpty)
        XCTAssert(scraped.interests.isEmpty)
        XCTAssertEqual(scraped.gender, "porpoise")
        XCTAssertEqual(scraped.postCount, 1954)
        XCTAssertEqual(scraped.postRate, "0.88")
    }
    
    func testWithAvatarAndGangTag() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile2")
        XCTAssertEqual(scraped.location, "San Francisco")
        XCTAssert(scraped.author.customTitle.contains("safs/titles"))
        XCTAssert(scraped.author.customTitle.contains("dd/68"))
        XCTAssert(scraped.author.customTitle.contains("01/df"))
    }
    
    func testWithFunkyText() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile3")
        XCTAssert(scraped.author.customTitle.contains("<i>"))
        XCTAssert(scraped.author.customTitle.contains("I'm getting at is"))
        XCTAssert(scraped.author.customTitle.contains("safs/titles"))
    }
    
    func testWithNoAvatarOrTitle() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile4")
        XCTAssert(scraped.author.customTitle.contains("<br"))
    }
    
    func testStupidNewbie() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile5")
        XCTAssert(scraped.author.customTitle.contains("newbie.gif"))
    }
    
    func testWithGangTagButNoAvatar() throws {
        let scraped = try scrapeHTMLFixture(ProfileScrapeResult.self, named: "profile6")
        XCTAssert(scraped.author.customTitle.contains("i am winner"))
        XCTAssert(scraped.author.customTitle.contains("tccburnouts.png"))
    }
}
