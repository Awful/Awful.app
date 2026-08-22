//  ArchivesFormScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader
import XCTest

final class ArchivesFormScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    /// A live forumdisplay page (not in archives mode). The year `<select>` marks its first option
    /// selected even when inactive, so `isActive` must come from the class, not a selected option.
    func testInactiveForm() throws {
        let scraped = try scrapeHTMLFixture(ArchivesFormScrapeResult.self, named: "forumdisplay")
        XCTAssertFalse(scraped.isActive)
        XCTAssertNil(scraped.selectedTimeframe)
        XCTAssertEqual(scraped.availableYears, [2013, 2012, 2011, 2010, 2009, 2008, 2007, 2006, 2005, 2004, 2003, 2002, 2001])
    }

    /// An engaged archives page: February 3, 2011 selected. 2011 is not the first year option, proving
    /// we read the actually-selected `<option>` rather than the default first one.
    func testActiveForm() throws {
        let scraped = try scrapeHTMLFixture(ArchivesFormScrapeResult.self, named: "forumdisplay-archives-active")
        XCTAssertTrue(scraped.isActive)
        XCTAssertEqual(scraped.selectedTimeframe, ArchivesTimeframe(month: 2, day: 3, year: 2011))
        XCTAssertEqual(scraped.availableYears.first, 2013)
        XCTAssertEqual(scraped.availableYears.count, 13)
    }

    /// The form is only rendered for Archives-upgrade owners, so its absence throws (letting
    /// `ThreadListScrapeResult` embed it via `try?` and treat "no upgrade" as nil).
    func testAbsentFormThrows() {
        let html = "<body><div>No time machine here.</div></body>"
        XCTAssertThrowsError(try ArchivesFormScrapeResult(HTMLDocument(string: html), url: nil))
    }

    /// `ThreadListScrapeResult` carries the archives state for free on every load — present on a
    /// forumdisplay page, nil on pages without the form (e.g. bookmarks).
    func testEmbeddedInThreadList() throws {
        let withForm = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: "forumdisplay")
        XCTAssertNotNil(withForm.archivesForm)
        XCTAssertFalse(withForm.archivesForm?.isActive ?? true)

        let withoutForm = try scrapeHTMLFixture(ThreadListScrapeResult.self, named: "bookmarkthreads")
        XCTAssertNil(withoutForm.archivesForm)
    }

    /// Year-only is a valid engaged timeframe (empty month/day options are selected → nil).
    func testYearOnlyTimeframe() throws {
        let scraped = try ArchivesFormScrapeResult(HTMLDocument(string: Self.activeForm(monthSelected: nil, daySelected: nil)), url: nil)
        XCTAssertTrue(scraped.isActive)
        XCTAssertEqual(scraped.selectedTimeframe, ArchivesTimeframe(month: nil, day: nil, year: 2015))
    }

    /// Month + year, no day.
    func testMonthAndYearTimeframe() throws {
        let scraped = try ArchivesFormScrapeResult(HTMLDocument(string: Self.activeForm(monthSelected: 2, daySelected: nil)), url: nil)
        XCTAssertEqual(scraped.selectedTimeframe, ArchivesTimeframe(month: 2, day: nil, year: 2015))
    }

    /// A day with no month is meaningless, so the day is dropped.
    func testDayWithoutMonthIsDropped() throws {
        let scraped = try ArchivesFormScrapeResult(HTMLDocument(string: Self.activeForm(monthSelected: nil, daySelected: 3)), url: nil)
        XCTAssertEqual(scraped.selectedTimeframe, ArchivesTimeframe(month: nil, day: nil, year: 2015))
        XCTAssertNil(scraped.selectedTimeframe?.day)
    }

    /// Builds a minimal engaged (`class="active"`) archives form with the given month/day selected
    /// (nil selects the empty option) and year 2015 selected.
    private static func activeForm(monthSelected: Int?, daySelected: Int?) -> String {
        func monthOption(_ value: Int) -> String {
            "<option value=\"\(value)\"\(monthSelected == value ? " selected" : "")>m\(value)</option>"
        }
        func dayOption(_ value: Int) -> String {
            "<option\(daySelected == value ? " selected" : "")>\(value)</option>"
        }
        let emptyMonth = "<option value=\"\"\(monthSelected == nil ? " selected" : "")>&nbsp;</option>"
        let emptyDay = "<option value=\"\"\(daySelected == nil ? " selected" : "")>&nbsp;</option>"
        return """
        <body>
        <table id="forum" class="threadlist archives"></table>
        <form method="POST" action="/forumdisplay.php?forumid=1" id="ac_timemachine" class="active">
        <select name="ac_month">\(emptyMonth)\(monthOption(1))\(monthOption(2))\(monthOption(3))</select>
        <select name="ac_day">\(emptyDay)\(dayOption(1))\(dayOption(2))\(dayOption(3))</select>
        <select name="ac_year"><option selected>2015</option><option>2014</option><option>2013</option></select>
        <input type="submit" name="set" value="GO">
        <input type="submit" name="rem" value="Remove">
        </form>
        </body>
        """
    }
}
