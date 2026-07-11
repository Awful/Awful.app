//  AccountFeaturesScrapingTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import AwfulCore
import HTMLReader
import XCTest

final class AccountFeaturesScrapingTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        testInit()
    }

    func testAllUpgradesEnabled() throws {
        let scraped = try scrapeHTMLFixture(AccountFeaturesScrapeResult.self, named: "accountfeatures")
        XCTAssertTrue(scraped.hasPlatinum)
        XCTAssertTrue(scraped.hasArchives)
        XCTAssertTrue(scraped.hasNoAds)
    }

    /// A `<dt>` without the `enabled` class means the upgrade isn't active on the account.
    func testMixedUpgrades() throws {
        let html = """
        <body class="member_account_features"><div class="standard"><div class="inner">
        <dl class="features">
            <dt class="enabled">Platinum Upgrade</dt>
            <dd class="enabled"><h5>This feature is active on your account.</h5></dd>
            <dt class="disabled">Archives Upgrade</dt>
            <dd class="disabled"><h5>This feature is not active on your account.</h5></dd>
            <dt class="disabled">No-Ads Upgrade</dt>
            <dd class="disabled last"><h5>This feature is not active on your account.</h5></dd>
        </dl>
        </div></div></body>
        """
        let scraped = try AccountFeaturesScrapeResult(HTMLDocument(string: html), url: nil)
        XCTAssertTrue(scraped.hasPlatinum)
        XCTAssertFalse(scraped.hasArchives)
        XCTAssertFalse(scraped.hasNoAds)
    }

    /// A page without the feature list (e.g. a login-expired redirect) should throw rather than
    /// silently report "no upgrades", which would strip a Platinum user's Messages tab.
    func testMissingFeatureListThrows() {
        let html = "<body class=\"member_account_features\"><div>Please log in.</div></body>"
        XCTAssertThrowsError(try AccountFeaturesScrapeResult(HTMLDocument(string: html), url: nil))
    }
}
