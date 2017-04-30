//  ProfileScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class ProfileScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return ProfileScraper.self
    }
    
    func testWithAvatarAndText() {
        let scraper = scrapeFixtureNamed("profile") as! ProfileScraper
        XCTAssert(fetchAll(User.self, inContext: managedObjectContext).count == 1)
        let pokeyman = scraper.profile
        XCTAssert(pokeyman?.user.userID == "106125")
        XCTAssert(pokeyman?.user.username == "pokeyman")
        XCTAssert(pokeyman?.user.customTitleHTML!.range(of: "play?") != nil)
        XCTAssert(pokeyman?.user.customTitleHTML!.range(of: "title-pokeyman") != nil)
        XCTAssert(pokeyman?.icqName == "1234")
        XCTAssert(pokeyman?.aimName == nil)
        XCTAssert(pokeyman?.yahooName == nil)
        XCTAssert(pokeyman?.location == nil)
        XCTAssert(pokeyman?.interests == nil)
        XCTAssert(pokeyman?.gender == "porpoise")
        XCTAssert(pokeyman?.postCount == 1954)
        XCTAssert(pokeyman?.postRate == "0.88")
    }
    
    func testWithAvatarAndGangTag() {
        let scraper = scrapeFixtureNamed("profile2") as! ProfileScraper
        let ronald = scraper.profile
        XCTAssert(ronald?.location! == "San Francisco")
        XCTAssert(ronald?.user.customTitleHTML!.range(of: "safs/titles") != nil)
        XCTAssert(ronald?.user.customTitleHTML!.range(of: "dd/68") != nil)
        XCTAssert(ronald?.user.customTitleHTML!.range(of: "01/df") != nil)
    }
    
    func testWithFunkyText() {
        let scraper = scrapeFixtureNamed("profile3") as! ProfileScraper
        let rinkles = scraper.profile?.user
        XCTAssert(rinkles?.customTitleHTML?.range(of: "<i>") != nil)
        XCTAssert(rinkles?.customTitleHTML?.range(of: "I'm getting at is") != nil)
        XCTAssert(rinkles?.customTitleHTML?.range(of: "safs/titles") != nil)
    }
    
    func testWithNoAvatarOrTitle() {
        let scraper = scrapeFixtureNamed("profile4") as! ProfileScraper
        let crypticEdge = scraper.profile?.user
        XCTAssert(crypticEdge?.customTitleHTML?.range(of: "<br") != nil)
    }
    
    func testStupidNewbie() {
        let scraper = scrapeFixtureNamed("profile5") as! ProfileScraper
        let newbie = scraper.profile?.user
        XCTAssert(newbie?.customTitleHTML?.range(of: "newbie.gif") != nil)
    }
    
    func testWithGangTagButNoAvatar() {
        let scraper = scrapeFixtureNamed("profile6") as! ProfileScraper
        let gripper = scraper.profile?.user
        XCTAssert(gripper?.customTitleHTML?.range(of: "i am winner") != nil)
        XCTAssert(gripper?.customTitleHTML?.range(of: "tccburnouts.png") != nil)
    }
}
