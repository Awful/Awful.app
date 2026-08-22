//  AccountFeaturesScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// The logged-in user's purchased upgrades, scraped from the Account Features page
/// (`member.php?action=accountfeatures`), rendered with `<body class="member_account_features">`.
///
/// The page always lists every upgrade as a `<dt>` inside `<dl class="features">`; owned upgrades
/// carry `class="enabled"` on their `<dt>` (and matching `<dd>`), so a `<dt>` without that class
/// means the feature isn't active on the account.
public struct AccountFeaturesScrapeResult: ScrapeResult {

    /// Platinum grants private messaging, forum search, and image uploads.
    public let hasPlatinum: Bool

    /// Archives grants access to old posts/threads via the archives date chooser.
    public let hasArchives: Bool

    /// No-Ads removes advertisements from the site.
    public let hasNoAds: Bool

    public init(_ html: HTMLNode, url: URL?) throws {
        let body = try html.requiredNode(matchingSelector: "body")

        // Require the feature list so a login-expired/redirected page fails loudly rather than
        // silently reporting "no upgrades" (which would strip a Platinum user's Messages tab).
        guard body.firstNode(matchingParsedSelector: .cached("dl.features")) != nil else {
            throw ScrapingError.missingExpectedElement("dl.features")
        }

        let enabledTitles = body
            .nodes(matchingParsedSelector: .cached("dl.features > dt.enabled"))
            .map { $0.textContent.lowercased() }
        func enabled(_ needle: String) -> Bool { enabledTitles.contains { $0.contains(needle) } }

        hasPlatinum = enabled("platinum")
        hasArchives = enabled("archives")
        hasNoAds = enabled("no-ads") || enabled("no ads")
    }
}
