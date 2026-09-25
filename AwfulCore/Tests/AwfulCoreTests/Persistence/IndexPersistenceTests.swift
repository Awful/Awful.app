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

    // MARK: Duplicate rows

    /// The model has no uniqueness constraints, so a user can end up in the store twice. The
    /// moderator batch used to build its lookup with `Dictionary(uniqueKeysWithValues:)`, which
    /// traps on the duplicate and took the forum list down on every refresh until reinstall.
    func testDuplicateModeratorRowsAreMergedNotFatal() throws {
        // 31158 moderates forum 273 in the fixture.
        let genesplicerID = "31158"
        let first = User.insert(into: context)
        first.userID = genesplicerID
        first.username = "old name"
        let firstThread = AwfulThread.insert(into: context)
        firstThread.threadID = "1"
        firstThread.author = first

        let second = User.insert(into: context)
        second.userID = genesplicerID
        let secondThread = AwfulThread.insert(into: context)
        secondThread.threadID = "2"
        secondThread.author = second
        try context.save()

        try scrapeJSONFixture(IndexScrapeResult.self, named: "index").upsert(into: context)
        try context.save()

        let survivors = User.fetch(in: context) {
            $0.predicate = .init("\(\User.userID) = \(genesplicerID)")
        }
        XCTAssertEqual(survivors.count, 1, "the duplicate is deleted, not just skipped")
        let survivor = try XCTUnwrap(survivors.first)
        XCTAssertEqual(survivor.username, "Genesplicer")
        XCTAssertEqual(Set(survivor.threads.map(\.threadID)), ["1", "2"], "the duplicate's relationships fold into the survivor")
    }

    /// Forums and groups get the plain keep-first treatment: nothing merges them, but a doubled
    /// row must not crash the scrape either.
    func testDuplicateForumRowsDoNotTrap() throws {
        for _ in 0..<2 {
            let forum = Forum.insert(into: context)
            forum.forumID = "192"
        }
        for _ in 0..<2 {
            let group = ForumGroup.insert(into: context)
            group.groupID = "51"
        }
        try context.save()

        try scrapeIndex().upsert(into: context)
        try context.save()

        let gadgets = Forum.fetch(in: context) { $0.predicate = .init("\(\Forum.forumID) = \("192")") }
        XCTAssertEqual(gadgets.count, 2, "forums are not merged, only tolerated")
        let updated = try XCTUnwrap(gadgets.first { $0.name == "Inspect Your Gadgets" })
        XCTAssertEqual(updated.group?.groupID, "51")
    }

    // MARK: Forums the site stops listing

    /// Decodes the `index` fixture, optionally dropping, renaming, or overriding raw fields of
    /// forums (at any depth) by ID. Deriving both scrapes from the one fixture guarantees they
    /// differ in exactly the forums under test.
    private func scrapeIndex(
        dropping droppedIDs: Set<Int> = [],
        renaming renames: [Int: String] = [:],
        overriding overrides: [Int: [String: Any]] = [:]
    ) throws -> IndexScrapeResult {
        let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Fixtures")!
        var json = try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as! [String: Any]

        func keeping(_ forums: [[String: Any]]) -> [[String: Any]] {
            forums.compactMap { forum in
                guard let id = forum["id"] as? Int, !droppedIDs.contains(id) else { return nil }
                var forum = forum
                if let newTitle = renames[id] {
                    forum["title"] = newTitle
                }
                forum.merge(overrides[id] ?? [:]) { $1 }
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

    func testRenamedForumAndGroupFollowTheSite() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let gadgets = try fetchGadgets()
        XCTAssertEqual(gadgets.name, "Inspect Your Gadgets")
        let discussion = try XCTUnwrap(ForumGroup.findOrFetch(in: context, matching: .init("\(\ForumGroup.groupID) = \("51")")))
        XCTAssertEqual(discussion.name, "Discussion")

        try scrapeIndex(renaming: [192: "Gadget Grotto", 51: "Discourse"]).upsert(into: context)
        try context.save()

        XCTAssertEqual(gadgets.name, "Gadget Grotto")
        XCTAssertEqual(discussion.name, "Discourse")
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

    // MARK: Malformed subforums

    private func fetchForum(_ forumID: String) throws -> Forum {
        try XCTUnwrap(Forum.findOrFetch(in: context, matching: .init("\(\Forum.forumID) = \(forumID)")))
    }

    /// 21 is "Comedy Goldmine", whose subforums in the fixture are 264, 115 and 176.
    private func assertListedUnderGoldmine(_ forumIDs: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        for forumID in forumIDs {
            let forum = try fetchForum(forumID)
            XCTAssertGreaterThanOrEqual(forum.index, 0, "\(forumID) is listed", file: file, line: line)
            XCTAssertEqual(forum.parentForum?.forumID, "21", "\(forumID) is under the Goldmine", file: file, line: line)
        }
    }

    /// The site sent BYOB Goldmine's description as the number 5, which used to throw out every
    /// Goldmine subforum along with it.
    func testNumericDescriptionKeepsSubforums() throws {
        try scrapeIndex(overriding: [176: ["description": 5]]).upsert(into: context)
        try context.save()

        try assertListedUnderGoldmine(["264", "115", "176"])
    }

    func testMalformedSubforumOnlyDropsItself() throws {
        try scrapeIndex(overriding: [176: ["title": ["nope"]]]).upsert(into: context)
        try context.save()

        try assertListedUnderGoldmine(["264", "115"])
        XCTAssertNil(Forum.findOrFetch(in: context, matching: .init("\(\Forum.forumID) = \("176")")))
    }

    /// Installs that already hid the Goldmine subforums get them back on the next refresh.
    func testDelistedSubforumsReturnDespiteNumericDescription() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()
        try scrapeIndex(dropping: [264, 115, 176]).upsert(into: context)
        try context.save()
        XCTAssertEqual(try fetchForum("264").index, -1)

        try scrapeIndex(overriding: [176: ["description": 5]]).upsert(into: context)
        try context.save()

        try assertListedUnderGoldmine(["264", "115", "176"])
    }

    /// A scrape that skipped something can't tell a forum the site dropped from one it couldn't
    /// read, so it hides nothing.
    func testSkippedForumsPauseDelisting() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        try scrapeIndex(dropping: [192], overriding: [176: ["title": ["nope"]]]).upsert(into: context)
        try context.save()

        XCTAssertGreaterThanOrEqual(try fetchForum("176").index, 0, "the unreadable forum stays put")
        XCTAssertGreaterThanOrEqual(try fetchGadgets().index, 0, "no delisting while something was skipped")

        try scrapeIndex(dropping: [192]).upsert(into: context)
        try context.save()

        XCTAssertEqual(try fetchGadgets().index, -1, "a clean scrape delists as usual")
    }

    func testMalformedGroupKeepsItsForums() throws {
        try scrapeIndex().upsert(into: context)
        try context.save()

        let archives = try XCTUnwrap(ForumGroup.findOrFetch(in: context, matching: .init("\(\ForumGroup.groupID) = \("49")")))
        let visibleBefore = visibleForumCount()

        try scrapeIndex(overriding: [49: ["has_threads": "sometimes"]]).upsert(into: context)
        try context.save()

        XCTAssertGreaterThanOrEqual(archives.index, 0)
        XCTAssertTrue(archives.forums.allSatisfy { $0.index >= 0 })
        XCTAssertEqual(visibleForumCount(), visibleBefore)
        XCTAssertGreaterThanOrEqual(try fetchGadgets().index, 0, "the other groups still update")
    }
}
