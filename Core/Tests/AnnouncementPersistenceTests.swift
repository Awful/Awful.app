//  AnnouncementPersistenceTests.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import CoreData
import XCTest

final class AnnouncementPersistenceTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        makeUTCDefaultTimeZone()

        let modelURL = Bundle(for: Announcement.self).url(forResource: "Awful", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = psc
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }

    private func scrapeThreadList(named basename: String) throws {
        let fixture = try scrapeFixture(named: basename) as ThreadListScrapeResult
        try _ = fixture.upsert(into: context)
    }

    private func scrapeAnnouncementList(named basename: String) throws {
        let fixture = try scrapeFixture(named: basename) as AnnouncementListScrapeResult
        try _ = fixture.upsert(into: context)
    }

    private func fetchAnnouncements() throws -> [Announcement] {
        let request = NSFetchRequest<Announcement>(entityName: Announcement.entityName())
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        return try context.fetch(request)
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
        XCTAssertEqual(announcement.postedDate?.timeIntervalSince1970, 1396904400)
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
            let fake = Announcement.insertIntoManagedObjectContext(context: context)
            fake.authorCustomTitleHTML = "<marquee>wow"
            fake.authorUsername = "ugh"
            fake.bodyHTML = "</marquee>"
            fake.listIndex = 1
            fake.postedDate = Date()
            fake.title = "A fake announcement"

            let madeUp = Announcement.insertIntoManagedObjectContext(context: context)
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
        XCTAssertEqual(announcement.authorRegdate?.timeIntervalSince1970, 1177027200)
        XCTAssertEqual(announcement.authorUsername, "SA Support Robot")
        XCTAssert(announcement.bodyHTML.contains("Thanks for shopping in advance!"))
        XCTAssertEqual(announcement.listIndex, 0)
        XCTAssertEqual(announcement.postedDate?.timeIntervalSince1970, 1283644800)
        XCTAssertEqual(announcement.title, "National Change Your Password Day!")
    }
}
