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

    // MARK: Forums the site stops listing

    /// Decodes the `index` fixture, optionally dropping forums (at any depth) by ID. Deriving both
    /// scrapes from the one fixture guarantees they differ in exactly the forums under test.
    private func scrapeIndex(dropping droppedIDs: Set<Int> = []) throws -> IndexScrapeResult {
        let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Fixtures")!
        var json = try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as! [String: Any]

        func keeping(_ forums: [[String: Any]]) -> [[String: Any]] {
            forums.compactMap { forum in
                guard let id = forum["id"] as? Int, !droppedIDs.contains(id) else { return nil }
                var forum = forum
                if let subforums = forum["sub_forums"] as? [[String: Any]] {
                    forum["sub_forums"] = keeping(subforums)
                }
                return forum
            }
        }
        json["forums"] = keeping(json["forums"] as! [[String: Any]])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(IndexScrapeResult.self, from: try JSONSerialization.data(withJSONObject: json))
    }

    private func visibleForumCount() -> Int {
        Forum.count(in: context) {
            $0.predicate = .init("\(\Forum.metadata.visibleInForumList) == YES")
        }
    }

    /// 192 is "Inspect Your Gadgets": top level in group 51, no subforums of its own. It has to be
    /// top level, since subforums start out hidden anyway.
    private func fetchGadgets() throws -> Forum {
        try XCTUnwrap(Forum.findOrFetch(in: context, matching: .init("\(\Forum.forumID) = \("192")")))
    }

    func testDelistedForumIsHiddenButKept() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let gadgets = try fetchGadgets()
        XCTAssertTrue(gadgets.metadata.visibleInForumList)
        XCTAssertGreaterThanOrEqual(gadgets.index, 0)

        gadgets.metadata.favorite = true
        gadgets.metadata.favoriteIndex = 1
        let forumCount = Forum.count(in: context)

        try scrapeIndex(dropping: [192]).upsert(into: context)
        try context.save()

        XCTAssertEqual(Forum.count(in: context), forumCount, "delisted forums are hidden, not deleted")
        XCTAssertFalse(gadgets.metadata.visibleInForumList)
        XCTAssertEqual(gadgets.index, -1)
        XCTAssertTrue(gadgets.metadata.favorite, "the favorite survives so it returns when the forum does")
        XCTAssertEqual(gadgets.metadata.favoriteIndex, 1)
    }

    func testRelistedForumComesBack() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let gadgets = try fetchGadgets()
        gadgets.metadata.favorite = true

        try scrapeIndex(dropping: [192]).upsert(into: context)
        try context.save()
        XCTAssertEqual(gadgets.index, -1)

        try scrapeIndex().upsert(into: context)
        try context.save()

        XCTAssertTrue(gadgets.metadata.visibleInForumList)
        XCTAssertGreaterThanOrEqual(gadgets.index, 0)
        XCTAssertTrue(gadgets.metadata.favorite)
    }

    func testDelistedGroupIsHidden() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let archives = try XCTUnwrap(ForumGroup.findOrFetch(in: context, matching: .init("\(\ForumGroup.groupID) = \("49")")))
        let groupCount = ForumGroup.count(in: context)
        XCTAssertFalse(archives.forums.isEmpty)

        // Dropping group 49 ("Archives") takes its forums with it.
        try scrapeIndex(dropping: [49]).upsert(into: context)
        try context.save()

        XCTAssertEqual(ForumGroup.count(in: context), groupCount)
        XCTAssertEqual(archives.index, -1)
        XCTAssertTrue(archives.forums.allSatisfy { $0.index == -1 && !$0.metadata.visibleInForumList })
    }

    func testEmptyScrapeHidesNothing() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let visibleBefore = visibleForumCount()
        XCTAssertGreaterThan(visibleBefore, 0)

        try scrapeIndex(dropping: [48, 51, 152, 153, 49]).upsert(into: context)
        try context.save()

        XCTAssertEqual(visibleForumCount(), visibleBefore)
    }
}
