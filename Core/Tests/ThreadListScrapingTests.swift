//  ThreadListScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class ThreadListScrapingTests: XCTestCase {
    override class func setUp() {
        super.setUp()

        makeUTCDefaultTimeZone()
    }
    
    func testAskTellThreadList() {
        let result = try! scrapeFixture(named: "showthread-asktell") as ThreadListScrapeResult
        XCTAssertFalse(result.isBookmarkedThreadsPage)
        let stupidQuestions = result.threads[0]
        let askIconURL = stupidQuestions.secondaryIcon?.url
        XCTAssertEqual(askIconURL.map(ThreadTag.imageName), "ama")
    }
    
    func testBookmarkedThreadList() {
        let result = try! scrapeFixture(named: "bookmarkthreads") as ThreadListScrapeResult
        XCTAssertEqual(result.threads.count, 11)
        XCTAssert(result.isBookmarkedThreadsPage)
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.pageNumber, 1)

        XCTAssertEqual(result.breadcrumbs?.forums.count, 0)

        let allUsernames = (result.announcements.map { $0.authorUsername }
            + result.threads.map { $0.authorUsername }
            + result.threads.map { $0.lastPostAuthorUsername})
            .filter { !$0.isEmpty }
            .sorted()

        XCTAssertEqual(allUsernames, [
            "Captain Vittles", "Choochacacko", "Dreylad", "Ferg", "Gazpacho", "I am in", "MC Fruit Stripe",
            "ManicJason", "Mug", "Ranma4703", "Salaminizer", "Scaevolus", "Scaevolus", "Sir Davey",
            "Suspicious Dish", "cougar cub", "csammis", "escape artist", "multigl", "pokeyman", "spankmeister",
            "sund"])
        
        let wireThread = result.threads.first { $0.title.hasPrefix("The Wire") }!
        XCTAssertEqual(wireThread.bookmark, .orange)
        XCTAssertEqual(wireThread.icon?.url.map(ThreadTag.imageName), "tava-vintage")
        XCTAssertEqual(wireThread.id.rawValue, "3522091")
        XCTAssertFalse(wireThread.isSticky)
        XCTAssertEqual(wireThread.title, "The Wire: The Rewatch... and all the pieces matter.")
        XCTAssertFalse(wireThread.isUnread)
        XCTAssertNil(wireThread.unreadPostCount)
        XCTAssertEqual(wireThread.authorUsername, "escape artist")
        XCTAssertEqual(wireThread.replyCount, 434)
        XCTAssertNil(wireThread.ratingAverage)
        XCTAssertNil(wireThread.ratingCount)
        XCTAssertEqual(wireThread.lastPostDate?.timeIntervalSince1970, 1357964700)
        XCTAssertEqual(wireThread.lastPostAuthorUsername, "MC Fruit Stripe")
        
        let cocfaq = result.threads.first { $0.title.contains("FAQ") }!
        XCTAssertEqual(cocfaq.bookmark, .orange)
        XCTAssertEqual(cocfaq.icon?.url.map(ThreadTag.imageName), "help")
        XCTAssertEqual(cocfaq.id.rawValue, "2836504")
        XCTAssert(cocfaq.isSticky)
        XCTAssertEqual(cocfaq.title, "Cavern of Cobol FAQ (Read this first)")
        XCTAssertNil(cocfaq.unreadPostCount)
        XCTAssertFalse(cocfaq.isUnread)
        XCTAssertEqual(cocfaq.authorUsername, "Scaevolus")
        XCTAssertEqual(cocfaq.replyCount, 0)
        XCTAssertNil(cocfaq.ratingAverage)
        XCTAssertEqual(cocfaq.lastPostDate?.timeIntervalSince1970, 1209381240)
        XCTAssertEqual(cocfaq.lastPostAuthorUsername, "Scaevolus")
        
        let androidAppThread = result.threads.first { $0.authorUsername == "Ferg" }!
        XCTAssertEqual(androidAppThread.bookmark, .red)
        XCTAssertEqual(androidAppThread.ratingCount, 159)
        XCTAssertEqual(androidAppThread.ratingAverage, 4.79)
    }
    
    func testDebateAndDiscussionThreadList() {
        let result = try! scrapeFixture(named: "forumdisplay") as ThreadListScrapeResult
        XCTAssertEqual(result.threads.count, 40)
        XCTAssertFalse(result.isBookmarkedThreadsPage)

        XCTAssertEqual(result.breadcrumbs?.forums.count, 2)
        XCTAssertEqual(result.breadcrumbs?.forums[0].name, "Discussion")
        XCTAssertEqual(result.breadcrumbs?.forums[1].name, "Debate & Discussion")
        XCTAssertEqual(result.breadcrumbs?.forums[1].id.rawValue, "46")

        let allUsernames = (result.threads.map { $0.authorUsername }
            + result.threads.map { $0.lastPostAuthorUsername }
            + result.announcements.map { $0.authorUsername })
            .filter { !$0.isEmpty }
            .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(allUsernames, [
            ".Edward Penischin", "a bad enough dude", "Amarkov", "Bedlamdan", "BiggerBoat", "blackguy32",
            "CatCannons", "Chamale", "Charliegrs", "Chopstix", "Cleretic", "coolskillrex remix",
            "cougar cub", "d3c0y2", "Delta-Wye", "Deteriorata", "Doc Hawkins", "Dreylad", "evilweasel",
            "Fire", "Fire", "Fluo", "Fluo", "Fried Chicken", "front wing flexing", "FUCK SNEEP", "FViral",
            "GAS CURES KIKES", "hambeet", "Helsing", "Helsing", "Helsing", "Install Gentoo", "Install Gentoo",
            "jeffersonlives", "Job Truniht", "Joementum", "Joementum", "Joementum", "Joementum", "Landsknecht",
            "Lascivious Sloth", "lonelywurm", "Lowtax", "MaterialConceptual", "MiracleMouse",
            "Moist von Lipwig", "MonsterUnderYourBed", "Mr. Wynand", "NovemberMike", "Pesmerga", "Petey",
            "Pobama", "Pobama", "Rexroom", "richardfun", "rudatron", "Salaminizer", "shots shots shots",
            "showbiz_liz", "SilentD", "Sir Kodiak", "Solkanar512", "Stefu", "SubponticatePoster",
            "TerminalSaint", "The Entire Universe", "The Selling Wizard", "thefncrow", "TheOtherContraGuy",
            "tonelok", "UltimoDragonQuest", "UltimoDragonQuest", "Vilerat", "watt par", "Wolfsheim", "WYA",
            "Xachariah", "Xandu", "XyloJW", "Zikan"])

        XCTAssertEqual(result.filterableIcons.count, 106)
        let firstIcon = result.filterableIcons[0]
        XCTAssertEqual(firstIcon.id, "357")
        XCTAssertEqual(firstIcon.url.map(ThreadTag.imageName), "dd-offmeds")
        let lastTag = result.filterableIcons.last!
        XCTAssertEqual(lastTag.id, "245")
        XCTAssertEqual(lastTag.url.map(ThreadTag.imageName), "tcc-weed")
        
        let rulesThread = result.threads.first { $0.title.contains("Improved Rules") }!
        XCTAssertEqual(rulesThread.bookmark, .none)
        XCTAssertEqual(rulesThread.icon?.url.map(ThreadTag.imageName), "icon23-banme")
        XCTAssertEqual(rulesThread.id.rawValue, "3332697")
        XCTAssert(rulesThread.isSticky)
        XCTAssertEqual(rulesThread.title, "The Improved Rules of Debate and Discussion - New Update")
        XCTAssertNil(rulesThread.unreadPostCount)
        XCTAssertEqual(rulesThread.authorUsername, "tonelok")
        XCTAssertEqual(rulesThread.replyCount, 11)
        XCTAssertNil(rulesThread.ratingCount)
        XCTAssertNil(rulesThread.ratingAverage)
        XCTAssertEqual(rulesThread.lastPostDate?.timeIntervalSince1970, 1330198920)
        XCTAssertEqual(rulesThread.lastPostAuthorUsername, "Xandu")
        
        let venezuelanThread = result.threads.first { $0.title.hasPrefix("Venezuelan") }!
        XCTAssertEqual(venezuelanThread.bookmark, .none)
        XCTAssertEqual(venezuelanThread.icon?.url.map(ThreadTag.imageName), "lf-marx")
        XCTAssertEqual(venezuelanThread.id.rawValue, "3510719")
        XCTAssertFalse(venezuelanThread.isSticky)
        XCTAssertEqual(venezuelanThread.title, "Venezuelan elections")
        XCTAssertNil(venezuelanThread.unreadPostCount)
        XCTAssert(venezuelanThread.isUnread)
        XCTAssertEqual(venezuelanThread.authorUsername, "a bad enough dude")
        XCTAssertEqual(venezuelanThread.replyCount, 410)
        XCTAssertNil(venezuelanThread.ratingCount)
        XCTAssertNil(venezuelanThread.ratingAverage)
        XCTAssertEqual(venezuelanThread.lastPostDate?.timeIntervalSince1970, 1357082460)
        XCTAssertEqual(venezuelanThread.lastPostAuthorUsername, "d3c0y2")
    }
    
    func testSubforumHierarchy() {
        let result = try! scrapeFixture(named: "forumdisplay2") as ThreadListScrapeResult
        let breadcrumbs = result.breadcrumbs!
        XCTAssertEqual(breadcrumbs.forums.count, 3)

        let discussion = breadcrumbs.forums[0]
        XCTAssertEqual(discussion.name, "Discussion")

        let games = breadcrumbs.forums[1]
        XCTAssertEqual(games.name, "Games")

        let lp = breadcrumbs.forums[2]
        XCTAssertEqual(lp.name, "Let's Play!")
    }
    
    func testAcceptsNewThreads() {
        do {
            let result = try! scrapeFixture(named: "forumdisplay2") as ThreadListScrapeResult
            XCTAssert(result.canPostNewThread)
        }

        do {
            let result = try! scrapeFixture(named: "forumdisplay-goldmine") as ThreadListScrapeResult
            XCTAssertFalse(result.canPostNewThread)
        }
    }
}
