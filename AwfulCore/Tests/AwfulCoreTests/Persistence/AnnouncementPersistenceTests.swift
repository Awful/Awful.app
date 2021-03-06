//  AnnouncementPersistenceTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import XCTest

final class AnnouncementPersistenceTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override class func setUp() {
        super.setUp()
        testInit()
    }

    override func setUp() {
        super.setUp()

        context = makeInMemoryStoreContext()
    }
    
    override func tearDown() {
        context = nil
        
        super.tearDown()
    }

    private func scrapeThreadList(named basename: String) throws {
        let fixture = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: basename)
        try _ = fixture.upsert(into: context)
        try _ = fixture.upsertAnnouncements(into: context)
    }

    private func scrapeAnnouncementList(named basename: String) throws {
        let fixture = try scrapeHTMLFixture(AnnouncementListScrapeResult.self, named: basename)
        try _ = fixture.upsert(into: context)
    }

    private func fetchAnnouncements() throws -> [Announcement] {
        Announcement.fetch(in: context) {
            $0.sortDescriptors = [.init(key: #keyPath(Announcement.listIndex), ascending: true)]
        }
    }
    
    func testNoAnnouncments() {
        try! scrapeThreadList(named: "forumdisplay2")
        XCTAssert(try! fetchAnnouncements().isEmpty)
    }

    func testInsertAnnouncements() {
        try! scrapeThreadList(named: "forumdisplay")

        let announcements = try! fetchAnnouncements()
        XCTAssertEqual(announcements.count, 1)

        let announcement = announcements[0]
        XCTAssertEqual(announcement.bodyHTML, "")
        XCTAssertEqual(announcement.listIndex, 0)
        XCTAssertEqual(announcement.postedDate?.timeIntervalSince1970, 1396922400)
        XCTAssertEqual(announcement.title, "National Change Your Password Day!")
        let author = announcement.author
        XCTAssertEqual(author?.userID, "27691")
        XCTAssertEqual(author?.username, "Lowtax")
        let threadTag = announcement.threadTag
        XCTAssertEqual(threadTag?.imageName, "icon-30-attnmod")
    }

    func testDeleteAnnouncements() {
        try! scrapeThreadList(named: "forumdisplay") // has announcements
        try! scrapeThreadList(named: "forumdisplay2") // no announcements

        XCTAssert(try! fetchAnnouncements().isEmpty)
    }

    func testUpdateAnnouncements() {
        do {
            let fake = Announcement.insert(into: context)
            fake.authorCustomTitleHTML = "<marquee>wow"
            fake.authorUsername = "ugh"
            fake.bodyHTML = "</marquee>"
            fake.listIndex = 1
            fake.postedDate = Date()
            fake.title = "A fake announcement"

            let madeUp = Announcement.insert(into: context)
            madeUp.authorCustomTitleHTML = "<sup>"
            madeUp.authorUsername = "ugh"
            madeUp.bodyHTML = "</sup>"
            madeUp.listIndex = 2
            madeUp.postedDate = Date()
            madeUp.title = "A made up announcement"

            try! context.save()
        }

        try! scrapeThreadList(named: "forumdisplay")

        let announcements = try! fetchAnnouncements()
        XCTAssertEqual(announcements.count, 1)

        let announcement = announcements[0]
        XCTAssertEqual(announcement.bodyHTML, "")
        XCTAssertEqual(announcement.title, "National Change Your Password Day!")
    }

    func testAnnouncementListBeforeThreadList() {
        try! scrapeAnnouncementList(named: "announcement")
        XCTAssert(try! fetchAnnouncements().isEmpty)
    }

    func testAnnouncementListAfterThreadList() {
        // The announcement list doesn't actually match the thread list, but we can't tell that, so this test should work anyway!
        try! scrapeThreadList(named: "forumdisplay")
        try! scrapeAnnouncementList(named: "announcement")

        let announcements = try! fetchAnnouncements()
        XCTAssertEqual(announcements.count, 1)

        let announcement = announcements[0]
        XCTAssert(announcement.authorCustomTitleHTML.contains("sa-support-robot.gif"))
        XCTAssertEqual(announcement.authorRegdate?.timeIntervalSince1970, 1177045200)
        XCTAssertEqual(announcement.authorUsername, "SA Support Robot")
        XCTAssert(announcement.bodyHTML.contains("Thanks for shopping in advance!"))
        XCTAssertEqual(announcement.listIndex, 0)
        XCTAssertEqual(announcement.postedDate?.timeIntervalSince1970, 1283662800)
        XCTAssertEqual(announcement.title, "National Change Your Password Day!")
    }
}
