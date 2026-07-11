//  AccountFeaturesRefresher.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Foundation
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountFeaturesRefresher")

/// Fetches the logged-in user's purchased upgrades and writes the derived settings. Returns the
/// scrape result, or throws (callers keep the last-known stored values on failure).
///
/// Besides the three feature flags, this derives `canSendPrivateMessages` from Platinum ownership:
/// Platinum is what grants private messaging and search, so it's the real source of truth for the
/// gates that flag drives (Messages tab, Search button, "send PM" actions).
@MainActor @discardableResult
func refreshAccountFeatures(client: ForumsClient = .shared) async throws -> AccountFeaturesScrapeResult {
    let features = try await client.accountFeatures()
    let defaults = UserDefaults.standard
    // AwfulSettings exposes a `value(for:)` getter but no typed setter — write via the raw key
    // (KVC), which fires KVO so `@AppStorage` and Foil's publishers update live.
    defaults.set(features.hasPlatinum, forKey: Settings.hasPlatinum.key)
    defaults.set(features.hasArchives, forKey: Settings.hasArchives.key)
    defaults.set(features.hasNoAds, forKey: Settings.hasNoAds.key)
    defaults.set(features.hasPlatinum, forKey: Settings.canSendPrivateMessages.key)
    return features
}

/// Periodically refreshes the logged-in user's purchased upgrades (Platinum, Archives, No-Ads).
///
/// Unlike `PrivateMessageInboxRefresher`, this must *not* gate on `canSendPrivateMessages`: doing so
/// would prevent ever detecting a newly purchased Platinum upgrade (the flag would be false, so we'd
/// never re-check and never flip it true).
final class AccountFeaturesRefresher {
    private let client: ForumsClient
    private let minder: RefreshMinder
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []

    init(client: ForumsClient, minder: RefreshMinder) {
        self.client = client
        self.minder = minder

        startTimer(reason: .initialization)

        tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: UIApplication.shared, queue: .main, using: { [unowned self] notification in

            self.startTimer(reason: .willEnterForeground)
        }))

        tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared, queue: .main, using: { [unowned self] notification in

            self.timer?.invalidate()
        }))
    }

    deinit {
        timer?.invalidate()
        tokens.forEach(NotificationCenter.default.removeObserver)
    }

    func refreshIfNecessary() {
        timer?.invalidate()

        guard client.isLoggedIn,
              minder.shouldRefresh(.accountFeatures) else
        {
            logger.debug("can't refresh account features yet, will try again later")
            return startTimer(reason: .failure)
        }

        Task {
            do {
                _ = try await refreshAccountFeatures(client: client)
                logger.debug("successfully refreshed account features")

                minder.didRefresh(.accountFeatures)

                startTimer(reason: .success)
            } catch {
                logger.warning("error refreshing account features, will try again later: \(error)")

                startTimer(reason: .failure)
            }
        }
    }

    private enum TimerReason {
        case initialization, success, failure, willEnterForeground
    }

    private func startTimer(reason: TimerReason) {
        let interval: TimeInterval = {
            let suggestion = minder.suggestedRefreshDate(.accountFeatures).timeIntervalSinceNow

            switch reason {
            case .success:
                return suggestion

            case .initialization where suggestion < 20,
                 .failure where suggestion <= 20,
                 .willEnterForeground where suggestion <= 20:
                // Some random time in the next couple minutes
                return 20 + TimeInterval(arc4random_uniform(90))

            case .initialization, .failure, .willEnterForeground:
                return suggestion
            }
        }()

        logger.debug("next automatic account features refresh is in \(interval) seconds")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] timer in
            self?.refreshIfNecessary()
        }
    }
}
