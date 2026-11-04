//  ProbationNoticeStore.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Foundation

/// Persists the logged-in user's probation notice so it survives relaunch and shows in Settings, and remembers which notice the user dismissed from the thread list banners.
///
/// Writes go through the raw keys, which fires KVO so `@AppStorage` and Foil publishers update live.
@MainActor
enum ProbationNoticeStore {
    private static var defaults: UserDefaults { .standard }

    /// While set, scraped notices are ignored so a simulated probation survives thread list loads. Kept in memory only, so relaunching ends the simulation and the next load clears the stored notice.
    private static var isSimulating = false

    /// The stored notice, or `nil` when the user isn't on probation.
    static var current: ProbationNoticeScrapeResult? {
        guard let message = defaults.value(for: Settings.probationMessage), !message.isEmpty else { return nil }
        return ProbationNoticeScrapeResult(title: defaults.value(for: Settings.probationTitle) ?? "", message: message)
    }

    /// Whether the thread list banners should show. Settings ignores this and shows the notice whenever there is one.
    static var shouldShowBanner: Bool {
        guard let current else { return false }
        return current.message != defaults.value(for: Settings.dismissedProbationMessage)
    }

    /// Replaces the stored notice with the latest scraped one. A `nil` notice means the probation is over, so the dismissal is forgotten too.
    static func record(_ notice: ProbationNoticeScrapeResult?) {
        guard !isSimulating, notice != current else { return }
        if let notice {
            defaults.set(notice.title, forKey: Settings.probationTitle.key)
            defaults.set(notice.message, forKey: Settings.probationMessage.key)
        } else {
            defaults.removeObject(forKey: Settings.probationTitle.key)
            defaults.removeObject(forKey: Settings.probationMessage.key)
            defaults.removeObject(forKey: Settings.dismissedProbationMessage.key)
        }
    }

    /// Shows a pretend probation notice until relaunch, so testers can try the banner and Settings row without getting probated.
    static func simulate() {
        isSimulating = true
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        let endDate = formatter.string(from: Date().addingTimeInterval(24 * 60 * 60))
        defaults.removeObject(forKey: Settings.dismissedProbationMessage.key)
        defaults.set("TAKE A BREAK", forKey: Settings.probationTitle.key)
        defaults.set("You have been put on probation until \(endDate). You cannot post while on probation. This probation is simulated for testing and ends when you relaunch Awful.", forKey: Settings.probationMessage.key)
    }

    /// Hides the thread list banners until a different probation comes along.
    static func dismissCurrent() {
        guard let current else { return }
        defaults.set(current.message, forKey: Settings.dismissedProbationMessage.key)
    }
}

extension ProbationNoticeScrapeResult {
    /// A short description of the probation for banners and rows, e.g. "On probation until Nov 3, 2026 22:21".
    var localizedSummary: String {
        if let endDateText {
            String(format: LocalizedString("probation.banner.until"), endDateText)
        } else {
            LocalizedString("probation.banner.generic")
        }
    }
}
