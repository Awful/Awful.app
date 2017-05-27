//  ProfileScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class ProfileScrapingTests: XCTestCase {
    func testWithAvatarAndText() {
        let scraped = try! scrapeFixture(named: "profile") as ProfileScrapeResult
        XCTAssertEqual(scraped.userID.rawValue, "106125")
        XCTAssertEqual(scraped.username, "pokeyman")
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "play?"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "title-pokeyman"))
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
    
    func testWithAvatarAndGangTag() {
        let scraped = try! scrapeFixture(named: "profile2") as ProfileScrapeResult
        XCTAssertEqual(scraped.location, "San Francisco")
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "safs/titles"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "dd/68"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "01/df"))
    }
    
    func testWithFunkyText() {
        let scraped = try! scrapeFixture(named: "profile3") as ProfileScrapeResult
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "<i>"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "I'm getting at is"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "safs/titles"))
    }
    
    func testWithNoAvatarOrTitle() {
        let scraped = try! scrapeFixture(named: "profile4") as ProfileScrapeResult
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "<br"))
    }
    
    func testStupidNewbie() {
        let scraped = try! scrapeFixture(named: "profile5") as ProfileScrapeResult
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "newbie.gif"))
    }
    
    func testWithGangTagButNoAvatar() {
        let scraped = try! scrapeFixture(named: "profile6") as ProfileScrapeResult
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "i am winner"))
        XCTAssertNotNil(scraped.customTitle.rawValue.range(of: "tccburnouts.png"))
    }
}
