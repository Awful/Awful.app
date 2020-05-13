//  PostScrapingTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import XCTest

final class PostScrapingTests: XCTestCase {

    func testIgnoredPost() throws {
        let result = try scrapeHTMLFixture(ShowPostScrapeResult.self, named: "showpost")
        XCTAssertEqual(result.author.username, "The Dave")
        XCTAssert(result.post.body.contains("Which command?"))
        XCTAssertEqual(result.threadID?.rawValue, "3510131")
        XCTAssertEqual(result.threadTitle, "Awful iPhone/iPad app - error code -1002")
    }

    /**
     The SA Forums servers have old DST info and so do not observe the current DST rules in the USA, which first became active in 2007. (The data may be older, but that's the first missing datum noticed by this predominantly USA-centric userbase.) `parsePostDate(_:)` should deal with this.

     "Who cares?", you might (reasonably) ask? It's noticeable to anyone reading a post made during the one magical hour per year when we start DST. In the USA, clocks roll over from 1:59:59 AM to 3:00:00 AM, and no time exists on that day with 2 AM in the "hours" position. However, the SA Forums is waiting (erroneously) to make the jump in a few weeks, so it will send us nonexistent times that fall in this hour. Then we fail to parse the post date and show emptiness to the user.

     This incredibly mild inconvenience is what we're trying to avoid. Admittedly, we're expending effort entirely out of proportion with the damage that the user would otherwise incur, but that is Awful's raison d'être.
     */
    func testParsePostDate() throws {
        // For comparison, here's a formatter that *is* up-to-date with DST rules.
        let currentDST = DateFormatter()
        currentDST.locale = Locale(identifier: "en_US")
        currentDST.timeZone = TimeZone(identifier: "America/Chicago")!
        currentDST.dateFormat = "MMM d, yyyy h:mm a"

        // Actual 2010 DST start date in Chicago was March 14.
        XCTAssertNil(currentDST.date(from: "Mar 14, 2010 2:15 AM"))
        XCTAssertNotNil(PostDateFormatter.date(from: "Mar 14, 2010 2:15 AM"))

        // If 2010 still used the old rules, DST would've started in the USA on the first Sunday in April, the 4th. Perfect Forums Emulation would return nil for times between 2 AM and 3 AM, but it's way less painful to just parse it leniently and assume the Forums won't send us what it thinks are nonexistent dates.
        XCTAssertNotNil(PostDateFormatter.date(from: "Apr 4, 2010 2:15 AM"))
        XCTAssertNotNil(currentDST.date(from: "Apr 4, 2010 2:15 AM"))
    }
}
