//  ThreadListScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class ThreadListScrapingTests: ScrapingTestCase {
    
    override class func scraperClass() -> AnyClass {
        return AwfulThreadListScraper.self
    }
    
    func testAskTellThreadList() {
        let scraper = scrapeFixtureNamed("showthread-asktell") as AwfulThreadListScraper
        let stupidQuestions = scraper.threads.first as Thread
        let askTag = stupidQuestions.secondaryThreadTag!
        XCTAssertEqual(askTag.imageName!, "ama")
    }
    
    func testBookmarkedThreadList() {
        let scraper = scrapeFixtureNamed("bookmarkthreads") as AwfulThreadListScraper
        let scrapedThreads = scraper.threads
        XCTAssertTrue(scrapedThreads.count == 11)
        XCTAssertEqual(scrapedThreads.count, Thread.numberOfObjectsInManagedObjectContext(managedObjectContext))
        XCTAssertTrue(ForumGroup.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
        XCTAssertTrue(Forum.numberOfObjectsInManagedObjectContext(managedObjectContext) == 0)
        let allUsers = User.fetchAllInManagedObjectContext(managedObjectContext) as [User]
        let allUsernames = allUsers.map{$0.username!}.sorted { $0.caseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending }
        XCTAssertEqual(allUsernames, ["Choochacacko", "csammis", "Dreylad", "escape artist", "Ferg", "I am in", "pokeyman", "Ranma4703", "Salaminizer", "Scaevolus", "Sir Davey"])
        
        let wireThread = Thread.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "title BEGINSWITH 'The Wire'"))
        XCTAssertEqual(wireThread.starCategory, AwfulStarCategory.Orange.rawValue)
        XCTAssertEqual(wireThread.threadTag!.imageName!, "tava-vintage")
        XCTAssertFalse(wireThread.sticky)
        XCTAssertEqual(wireThread.title!, "The Wire: The Rewatch... and all the pieces matter.")
        XCTAssertTrue(wireThread.seenPosts == 435)
        XCTAssertEqual(wireThread.author!.username!, "escape artist")
        XCTAssertTrue(wireThread.totalReplies == 434)
        XCTAssertTrue(wireThread.numberOfVotes == 0)
        XCTAssertTrue(wireThread.rating == 0)
        XCTAssertTrue(wireThread.lastPostDate!.timeIntervalSince1970 == 1357964700)
        XCTAssertEqual(wireThread.lastPostAuthorName!, "MC Fruit Stripe")
        
        let CoCFAQ = Thread.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "title CONTAINS 'FAQ'"))
        XCTAssertEqual(CoCFAQ.starCategory, AwfulStarCategory.Orange.rawValue)
        XCTAssertEqual(CoCFAQ.threadTag!.imageName!, "help")
        XCTAssertTrue(CoCFAQ.sticky)
        XCTAssertTrue(CoCFAQ.stickyIndex == 0)
        XCTAssertEqual(CoCFAQ.title!, "Cavern of Cobol FAQ (Read this first)")
        XCTAssertTrue(CoCFAQ.seenPosts == 1)
        XCTAssertEqual(CoCFAQ.author!.username!, "Scaevolus")
        XCTAssertTrue(CoCFAQ.totalReplies == 0)
        XCTAssertTrue(CoCFAQ.rating == 0)
        XCTAssertEqual(CoCFAQ.lastPostDate!.timeIntervalSince1970, 1209381240)
        XCTAssertEqual(CoCFAQ.lastPostAuthorName!, "Scaevolus")
        
        let androidAppThread = Thread.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "author.username = 'Ferg'"))
        XCTAssertEqual(androidAppThread.starCategory, AwfulStarCategory.Red.rawValue)
        XCTAssertTrue(androidAppThread.numberOfVotes == 159)
        XCTAssertTrue(androidAppThread.rating == 4.79)
    }
    
    func testDebateAndDiscussionThreadList() {
        let scraper = scrapeFixtureNamed("forumdisplay") as AwfulThreadListScraper
        let scrapedThreads = scraper.threads
        XCTAssertTrue(scrapedThreads.count == 40)
        let allThreads = Thread.fetchAllInManagedObjectContext(managedObjectContext) as [Thread]
        XCTAssertEqual(allThreads.count, scrapedThreads.count);
        let allGroups = ForumGroup.fetchAllInManagedObjectContext(managedObjectContext) as [ForumGroup]
        XCTAssertTrue(allGroups.count == 1)
        let discussion = allGroups.first!
        XCTAssertEqual(discussion.name!, "Discussion")
        XCTAssertTrue(discussion.forums.count == 1)
        let allForums = Forum.fetchAllInManagedObjectContext(managedObjectContext) as [Forum]
        XCTAssertTrue(allForums.count == 1)
        let debateAndDiscussion = allForums.first!
        XCTAssertEqual(debateAndDiscussion.name!, "Debate & Discussion")
        XCTAssertEqual(debateAndDiscussion.forumID, "46")
        let threadForums = NSSet(array: allThreads.map{$0.forum!})
        XCTAssertEqual(threadForums, NSSet(object: debateAndDiscussion))
        let allUsers = User.fetchAllInManagedObjectContext(managedObjectContext) as [User]
        let allUsernames = allUsers.map{$0.username!}.sorted { $0.caseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending }
        XCTAssertEqual(allUsernames, [
            "a bad enough dude",
            "Bedlamdan",
            "BiggerBoat",
            "blackguy32",
            "CatCannons",
            "Chamale",
            "coolskillrex remix",
            "Dreylad",
            "evilweasel",
            "Fire",
            "Fluo",
            "Fried Chicken",
            "GAS CURES KIKES",
            "hambeet",
            "Helsing",
            "Joementum",
            "Landsknecht",
            "Lascivious Sloth",
            "lonelywurm",
            "MiracleMouse",
            "Pesmerga",
            "Petey",
            "Pobama",
            "Salaminizer",
            "showbiz_liz",
            "Sir Kodiak",
            "Solkanar512",
            "Stefu",
            "The Selling Wizard",
            "TheOtherContraGuy",
            "tonelok",
            "UltimoDragonQuest",
            "Vilerat",
            "WYA",
            "XyloJW",
            "Zikan"])
        let tags = debateAndDiscussion.threadTags.array as [ThreadTag]
        XCTAssertTrue(tags.count == 106)
        let firstTag = tags.first!
        XCTAssertEqual(firstTag.threadTagID!, "357")
        XCTAssertEqual(firstTag.imageName!, "dd-offmeds")
        let lastTag = tags.last!
        XCTAssertEqual(lastTag.threadTagID!, "245")
        XCTAssertEqual(lastTag.imageName!, "tcc-weed")
        
        let rulesThread = Thread.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "title CONTAINS 'Improved Rules'")) as Thread
        XCTAssertEqual(rulesThread.starCategory, AwfulStarCategory.None.rawValue)
        XCTAssertEqual(rulesThread.threadTag!.imageName!, "icon23-banme")
        XCTAssertTrue(rulesThread.sticky)
        XCTAssertTrue(rulesThread.stickyIndex != 0)
        XCTAssertEqual(rulesThread.title!, "The Improved Rules of Debate and Discussion - New Update")
        XCTAssertTrue(rulesThread.seenPosts == 12)
        XCTAssertEqual(rulesThread.author!.username!, "tonelok")
        XCTAssertTrue(rulesThread.totalReplies == 11)
        XCTAssertTrue(rulesThread.numberOfVotes == 0)
        XCTAssertTrue(rulesThread.rating == 0)
        XCTAssertEqual(rulesThread.lastPostDate!.timeIntervalSince1970, 1330198920)
        XCTAssertEqual(rulesThread.lastPostAuthorName!, "Xandu")
        
        let venezuelanThread = Thread.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "title BEGINSWITH 'Venezuelan'"))
        XCTAssertEqual(venezuelanThread.starCategory, AwfulStarCategory.None.rawValue)
        XCTAssertEqual(venezuelanThread.threadTag!.imageName!, "lf-marx")
        XCTAssertFalse(venezuelanThread.sticky)
        XCTAssertEqual(venezuelanThread.title!, "Venezuelan elections")
        XCTAssertTrue(venezuelanThread.seenPosts == 0)
        XCTAssertEqual(venezuelanThread.author!.username!, "a bad enough dude")
        XCTAssertTrue(venezuelanThread.totalReplies == 410)
        XCTAssertTrue(venezuelanThread.numberOfVotes == 0)
        XCTAssertTrue(venezuelanThread.rating == 0)
        XCTAssertEqual(venezuelanThread.lastPostDate!.timeIntervalSince1970, 1357082460)
        XCTAssertEqual(venezuelanThread.lastPostAuthorName!, "d3c0y2")
    }
    
    func testSubforumHierarchy() {
        scrapeFixtureNamed("forumdisplay2")
        let allForums = Forum.fetchAllInManagedObjectContext(managedObjectContext) as [Forum]
        XCTAssertTrue(allForums.count == 2)
        let allForumNames = allForums.map{$0.name!}.sorted(<)
        XCTAssertEqual(allForumNames, ["Games", "Let's Play!"])
        let allGroups = ForumGroup.fetchAllInManagedObjectContext(managedObjectContext) as [ForumGroup]
        XCTAssertTrue(allGroups.count == 1)
        let discussion = allGroups.first!
        XCTAssertEqual(discussion.forums.count, allForums.count)
        let games = Forum.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "name = 'Games'"))
        XCTAssertTrue(games.childForums.count == 1)
        let letsPlay = games.childForums.anyObject() as Forum
        XCTAssertEqual(letsPlay.name!, "Let's Play!")
    }
    
    func testAcceptsNewThreads() {
        scrapeFixtureNamed("forumdisplay2")
        scrapeFixtureNamed("forumdisplay-goldmine")
        
        let LP = Forum.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '191'")) as Forum
        XCTAssertTrue(LP.canPost)
        
        let goldmine = Forum.fetchArbitraryInManagedObjectContext(managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '21'"))
        XCTAssertFalse(goldmine.canPost)
    }
}
