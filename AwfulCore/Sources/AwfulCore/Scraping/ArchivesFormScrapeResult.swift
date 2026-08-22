//  ArchivesFormScrapeResult.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// A locked archives ("time machine") timeframe. `year` is always present when engaged (the year
/// `<select>` has no empty option); `month` and `day` are optional. A day is only meaningful with a
/// month, so `day` is forced to `nil` whenever `month` is `nil`.
public struct ArchivesTimeframe: Equatable, Hashable {
    public let month: Int?
    public let day: Int?
    public let year: Int

    public init(month: Int?, day: Int?, year: Int) {
        self.month = month
        self.day = month == nil ? nil : day
        self.year = year
    }
}

/// The `#ac_timemachine` archives form at the bottom of `forumdisplay.php`. It's only rendered for
/// users who own the Archives upgrade, so a missing form throws — letting callers embed this via
/// `try?` and treat "no upgrade" as a distinct (nil) case.
///
/// Engaging the time machine locks the *session* (server-side, cookie-scoped) into a past timeframe.
/// When engaged, the thread-list `<table id="forum">` gains an `archives` class and the form gains an
/// `active` class, and the form's `<option selected>`s reflect the current timeframe. Note the year
/// `<select>` marks its first `<option>` selected even when *inactive*, so a selected year is not a
/// reliable "is engaged" signal — the class is.
public struct ArchivesFormScrapeResult: ScrapeResult {

    /// Years offered by the site's `<select name="ac_year">`, newest first.
    public let availableYears: [Int]

    /// Whether the session is currently locked to an archived timeframe.
    public let isActive: Bool

    /// The engaged timeframe; non-`nil` only when `isActive`.
    public let selectedTimeframe: ArchivesTimeframe?

    public init(_ html: HTMLNode, url: URL?) throws {
        // Search the passed node directly (it may be the whole document or just its <body>, as when
        // `ThreadListScrapeResult` embeds this) — don't re-require a descendant <body>.
        guard let form = html.firstNode(matchingParsedSelector: .cached("form#ac_timemachine")) else {
            throw ScrapingError.missingExpectedElement("form#ac_timemachine")
        }

        // The form's `active` class is the canonical "engaged" signal; the thread-list table's
        // `archives` class corroborates it.
        let tableIsArchives = html
            .firstNode(matchingParsedSelector: .cached("table#forum"))?
            .hasClass("archives") ?? false
        isActive = form.hasClass("active") || tableIsArchives

        // Year options carry no `value` attribute, so read the text; drop the empty option.
        availableYears = form
            .nodes(matchingParsedSelector: .cached("select[name='ac_year'] option"))
            .compactMap { Self.intValue($0) }

        if isActive,
           let year = Self.selectedInt(in: form, "select[name='ac_year'] option[selected]") {
            let month = Self.selectedInt(in: form, "select[name='ac_month'] option[selected]")
            // The day `<select>` is named `ac_day` in some captures and `bday_day` in others; accept both.
            let day = Self.selectedInt(in: form, "select[name='ac_day'] option[selected]")
                ?? Self.selectedInt(in: form, "select[name='bday_day'] option[selected]")
            // `ArchivesTimeframe` drops a day without a month, guarding the orphan-day case.
            selectedTimeframe = ArchivesTimeframe(month: month, day: day, year: year)
        } else {
            // Ignore the default-selected year on an inactive form.
            selectedTimeframe = nil
        }
    }

    /// The integer value of an `<option>`, preferring its `value` attribute and falling back to its
    /// text (year/day options have no `value`).
    private static func intValue(_ option: HTMLElement) -> Int? {
        Int((option["value"] ?? option.textContent).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func selectedInt(in form: HTMLElement, _ selector: String) -> Int? {
        form.firstNode(matchingParsedSelector: .cached(selector)).flatMap(intValue)
    }
}
