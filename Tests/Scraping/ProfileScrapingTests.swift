//  ProfileScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class ProfileScrapingTests: ScrapingTestCase {
    
    override class func scraperClass() -> AnyClass {
        return ProfileScraper.self
    }
    
    func testWithAvatarAndText() {
        let scraper = scrapeFixtureNamed("profile") as ProfileScraper
        XCTAssertTrue(User.numberOfObjectsInManagedObjectContext(managedObjectContext) == 1)
        let pokeyman = scraper.profile
        XCTAssertEqual(pokeyman.user.userID!, "106125")
        XCTAssertEqual(pokeyman.user.username!, "pokeyman")
        XCTAssertTrue(pokeyman.user.customTitleHTML!.rangeOfString("play?") != nil)
        XCTAssertTrue(pokeyman.user.customTitleHTML!.rangeOfString("title-pokeyman") != nil)
        XCTAssertEqual(pokeyman.icqName!, "1234")
        XCTAssertNil(pokeyman.aimName)
        XCTAssertNil(pokeyman.yahooName)
        XCTAssertNil(pokeyman.location)
        XCTAssertNil(pokeyman.interests)
        XCTAssertEqual(pokeyman.gender!, "porpoise")
        XCTAssertTrue(pokeyman.postCount == 1954)
        XCTAssertTrue(pokeyman.postRate == "0.88")
    }
    
    func testWithAvatarAndGangTag() {
        let scraper = scrapeFixtureNamed("profile2") as ProfileScraper
        let ronald = scraper.profile
        XCTAssertEqual(ronald.location!, "San Francisco")
        XCTAssertTrue(ronald.user.customTitleHTML!.rangeOfString("safs/titles") != nil)
        XCTAssertTrue(ronald.user.customTitleHTML!.rangeOfString("dd/68") != nil)
        XCTAssertTrue(ronald.user.customTitleHTML!.rangeOfString("01/df") != nil)
    }
    
    func testWithFunkyText() {
        let scraper = scrapeFixtureNamed("profile3") as ProfileScraper
        let rinkles = scraper.profile.user
        XCTAssertTrue(rinkles.customTitleHTML!.rangeOfString("<i>") != nil)
        XCTAssertTrue(rinkles.customTitleHTML!.rangeOfString("I'm getting at is") != nil)
        XCTAssertTrue(rinkles.customTitleHTML!.rangeOfString("safs/titles") != nil)
    }
    
    func testWithNoAvatarOrTitle() {
        let scraper = scrapeFixtureNamed("profile4") as ProfileScraper
        let crypticEdge = scraper.profile.user
        XCTAssertTrue(crypticEdge.customTitleHTML!.rangeOfString("<br") != nil)
    }
    
    func testStupidNewbie() {
        let scraper = scrapeFixtureNamed("profile5") as ProfileScraper
        let newbie = scraper.profile.user
        XCTAssertTrue(newbie.customTitleHTML!.rangeOfString("newbie.gif") != nil)
    }
    
    func testWithGangTagButNoAvatar() {
        let scraper = scrapeFixtureNamed("profile6") as ProfileScraper
        let gripper = scraper.profile.user
        XCTAssertTrue(gripper.customTitleHTML!.rangeOfString("i am winner") != nil)
        XCTAssertTrue(gripper.customTitleHTML!.rangeOfString("tccburnouts.png") != nil)
    }
}
