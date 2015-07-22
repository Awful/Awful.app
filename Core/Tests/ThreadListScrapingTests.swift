//  ThreadListScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore

final class ThreadListScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return AwfulThreadListScraper.self
    }
    
    func testAskTellThreadList() {
        let scraper = scrapeFixtureNamed("showthread-asktell") as! AwfulThreadListScraper
        let stupidQuestions = scraper.threads.first as! Thread
        let askTag = stupidQuestions.secondaryThreadTag!
        XCTAssert(askTag.imageName == "ama")
    }
    
    func testBookmarkedThreadList() {
        let scraper = scrapeFixtureNamed("bookmarkthreads") as! AwfulThreadListScraper
        let scrapedThreads = scraper.threads
        XCTAssert(scrapedThreads.count == 11)
        XCTAssert(scrapedThreads.count == fetchAll(Thread.self, inContext: managedObjectContext).count)
        XCTAssert(fetchAll(ForumGroup.self, inContext: managedObjectContext).isEmpty)
        XCTAssert(fetchAll(Forum.self, inContext: managedObjectContext).isEmpty)
        let allUsers = fetchAll(User.self, inContext: managedObjectContext)
        let allUsernames = allUsers.map { $0.username! }.sort(<)
        XCTAssert(allUsernames == ["Choochacacko", "Dreylad", "Ferg", "I am in", "Ranma4703", "Salaminizer", "Scaevolus", "Sir Davey", "csammis", "escape artist", "pokeyman"])
        
        let wireThread = fetchOne(Thread.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "title BEGINSWITH 'The Wire'"))!
        XCTAssert(wireThread.starCategory == .Orange)
        XCTAssert(wireThread.threadTag!.imageName == "tava-vintage")
        XCTAssert(!wireThread.sticky)
        XCTAssert(wireThread.title == "The Wire: The Rewatch... and all the pieces matter.")
        XCTAssert(wireThread.seenPosts == 435)
        XCTAssert(wireThread.author!.username == "escape artist")
        XCTAssert(wireThread.totalReplies == 434)
        XCTAssert(wireThread.numberOfVotes == 0)
        XCTAssert(wireThread.rating == 0)
        XCTAssert(wireThread.lastPostDate!.timeIntervalSince1970 == 1357964700)
        XCTAssert(wireThread.lastPostAuthorName == "MC Fruit Stripe")
        
        let CoCFAQ = fetchOne(Thread.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "title CONTAINS 'FAQ'"))!
        XCTAssert(CoCFAQ.starCategory == .Orange)
        XCTAssert(CoCFAQ.threadTag!.imageName == "help")
        XCTAssert(CoCFAQ.sticky)
        XCTAssert(CoCFAQ.stickyIndex == 0)
        XCTAssert(CoCFAQ.title == "Cavern of Cobol FAQ (Read this first)")
        XCTAssert(CoCFAQ.seenPosts == 1)
        XCTAssert(CoCFAQ.author!.username == "Scaevolus")
        XCTAssert(CoCFAQ.totalReplies == 0)
        XCTAssert(CoCFAQ.rating == 0)
        XCTAssert(CoCFAQ.lastPostDate!.timeIntervalSince1970 == 1209381240)
        XCTAssert(CoCFAQ.lastPostAuthorName == "Scaevolus")
        
        let androidAppThread = fetchOne(Thread.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "author.username = 'Ferg'"))!
        XCTAssert(androidAppThread.starCategory == .Red)
        XCTAssert(androidAppThread.numberOfVotes == 159)
        XCTAssert(androidAppThread.rating == 4.79)
    }
    
    func testDebateAndDiscussionThreadList() {
        let scraper = scrapeFixtureNamed("forumdisplay") as! AwfulThreadListScraper
        let scrapedThreads = scraper.threads
        XCTAssert(scrapedThreads.count == 40)
        let allThreads = fetchAll(Thread.self, inContext: managedObjectContext)
        XCTAssert(allThreads.count == scrapedThreads.count);
        let allGroups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        XCTAssert(allGroups.count == 1)
        let discussion = allGroups.first!
        XCTAssert(discussion.name == "Discussion")
        XCTAssert(discussion.forums.count == 1)
        let allForums = fetchAll(Forum.self, inContext: managedObjectContext)
        XCTAssert(allForums.count == 1)
        let debateAndDiscussion = allForums.first!
        XCTAssert(debateAndDiscussion.name == "Debate & Discussion")
        XCTAssert(debateAndDiscussion.forumID == "46")
        let threadForums = NSSet(array: allThreads.map{$0.forum!})
        XCTAssert(threadForums == NSSet(object: debateAndDiscussion))
        let allUsers = fetchAll(User.self, inContext: managedObjectContext)
        let allUsernames = allUsers.map{$0.username!}.sort { $0.caseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending }
        XCTAssert(allUsernames == [
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
        let tags = debateAndDiscussion.threadTags.array as! [ThreadTag]
        XCTAssert(tags.count == 106)
        let firstTag = tags.first!
        XCTAssert(firstTag.threadTagID == "357")
        XCTAssert(firstTag.imageName == "dd-offmeds")
        let lastTag = tags.last!
        XCTAssert(lastTag.threadTagID == "245")
        XCTAssert(lastTag.imageName == "tcc-weed")
        
        let rulesThread = fetchOne(Thread.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "title CONTAINS 'Improved Rules'"))!
        XCTAssert(rulesThread.starCategory == .None)
        XCTAssert(rulesThread.threadTag!.imageName == "icon23-banme")
        XCTAssert(rulesThread.sticky)
        XCTAssert(rulesThread.stickyIndex != 0)
        XCTAssert(rulesThread.title == "The Improved Rules of Debate and Discussion - New Update")
        XCTAssert(rulesThread.seenPosts == 12)
        XCTAssert(rulesThread.author!.username == "tonelok")
        XCTAssert(rulesThread.totalReplies == 11)
        XCTAssert(rulesThread.numberOfVotes == 0)
        XCTAssert(rulesThread.rating == 0)
        XCTAssert(rulesThread.lastPostDate!.timeIntervalSince1970 == 1330198920)
        XCTAssert(rulesThread.lastPostAuthorName == "Xandu")
        
        let venezuelanThread = fetchOne(Thread.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "title BEGINSWITH 'Venezuelan'"))!
        XCTAssert(venezuelanThread.starCategory == .None)
        XCTAssert(venezuelanThread.threadTag!.imageName == "lf-marx")
        XCTAssertFalse(venezuelanThread.sticky)
        XCTAssert(venezuelanThread.title == "Venezuelan elections")
        XCTAssert(venezuelanThread.seenPosts == 0)
        XCTAssert(venezuelanThread.author!.username == "a bad enough dude")
        XCTAssert(venezuelanThread.totalReplies == 410)
        XCTAssert(venezuelanThread.numberOfVotes == 0)
        XCTAssert(venezuelanThread.rating == 0)
        XCTAssert(venezuelanThread.lastPostDate!.timeIntervalSince1970 == 1357082460)
        XCTAssert(venezuelanThread.lastPostAuthorName == "d3c0y2")
    }
    
    func testSubforumHierarchy() {
        scrapeFixtureNamed("forumdisplay2")
        let allForums = fetchAll(Forum.self, inContext: managedObjectContext)
        XCTAssert(allForums.count == 2)
        let allForumNames = allForums.map{$0.name!}.sort(<)
        XCTAssert(allForumNames == ["Games", "Let's Play!"])
        let allGroups = fetchAll(ForumGroup.self, inContext: managedObjectContext)
        XCTAssert(allGroups.count == 1)
        let discussion = allGroups.first!
        XCTAssert(discussion.forums.count == allForums.count)
        let games = fetchOne(Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "name = 'Games'"))!
        XCTAssert(games.childForums.count == 1)
        let letsPlay = games.childForums.anyObject() as! Forum
        XCTAssert(letsPlay.name == "Let's Play!")
    }
    
    func testAcceptsNewThreads() {
        scrapeFixtureNamed("forumdisplay2")
        scrapeFixtureNamed("forumdisplay-goldmine")
        
        let LP = fetchOne(Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '191'"))!
        XCTAssert(LP.canPost)
        
        let goldmine = fetchOne(Forum.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "forumID = '21'"))!
        XCTAssertFalse(goldmine.canPost)
    }
}
