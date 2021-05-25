//  IndexPersistenceTests.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import AwfulScraping
import CoreData
import XCTest

class IndexPersistentTests: XCTestCase {
    var context: NSManagedObjectContext!
    var lastModified: LastModifiedContextObserver!

    override class func setUp() {
        super.setUp()
        testInit()
    }

    override func setUp() {
        super.setUp()
        context = makeInMemoryStoreContext()
        lastModified = LastModifiedContextObserver(managedObjectContext: context)
    }

    override func tearDown() {
        context = nil
        lastModified = nil
        super.tearDown()
    }

    func testIndexPersistence() throws {
        XCTAssertEqual(Forum.count(in: context), 0)
        XCTAssertEqual(ForumGroup.count(in: context), 0)
        XCTAssertEqual(ForumMetadata.count(in: context), 0)
        XCTAssertEqual(User.count(in: context), 0)

        let result = try scrapeJSONFixture(IndexScrapeResult.self, named: "index")
        try result.upsert(into: context)
        try context.save()

        let main = ForumGroup.findOrFetch(in: context, matching: .init("\(\ForumGroup.groupID) = \("48")"))
        XCTAssertNotNil(main)
        XCTAssertEqual(main!.name, "Main")

        let mainForumNames =  main!.forums.compactMap { $0.name }.sorted()
        XCTAssertEqual(mainForumNames, [
            "BYOB: An Island of Chill in a Sea of Madness",
            "Cool Crew Chat Central",
            "E/N: Everyone's/Neurotic",
            "General Bullshit",
            "Post My Favorites",
            "Post Your Favorite (or Request): Stop! Collaborate and LISTen",
            "SA's Front Page Discussion",
            "The Cholesterol Clubhouse",
        ])

        let en = Forum.findOrFetch(in: context, matching: .init("\(\Forum.forumID) = \("214")"))
        XCTAssertNotNil(en)
        XCTAssertEqual(en!.group, main)
        XCTAssertEqual(en!.name, "E/N: Everyone's/Neurotic")
        XCTAssertNotNil(en!.parentForum)
        let gbs = en!.parentForum!
        XCTAssertEqual(gbs.group, main)
        XCTAssertEqual(gbs.name, "General Bullshit")

        let wow = Forum.findOrFetch(in: context, matching: .init("\(\Forum.forumID) = \("146")"))
        XCTAssertNotNil(wow)
        XCTAssertEqual(wow!.name, "WoW: Goon Squad")
        var wowPath: [Forum] = []
        do {
            var cur = wow
            while let parent = cur?.parentForum {
                wowPath.append(parent)
                cur = parent
            }
        }
        XCTAssertEqual(wowPath.map { $0.forumID }, ["259", "44"])

        let pokeyman = User.findOrFetch(in: context, matching: .init("\(\User.userID) = \("106125")"))
        XCTAssertNotNil(pokeyman)
        XCTAssertEqual(pokeyman!.username, "pokeyman")
        XCTAssertEqual(pokeyman!.profile!.aboutMe, "2")
    }
}
