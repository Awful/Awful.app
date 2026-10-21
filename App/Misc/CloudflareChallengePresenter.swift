//  CloudflareChallengePresenter.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudflareChallengePresenter")

/// Puts a `CloudflareChallengeViewController` on screen over whatever the user is looking at, and reports whether the challenge got cleared. Wired up as `ForumsClient.cloudflareChallengeHandler`.
@MainActor
final class CloudflareChallengePresenter {

    private let window: () -> UIWindow?

    init(window: @escaping () -> UIWindow?) {
        self.window = window
    }

    /// Presents the challenge and waits for the user to clear or cancel it. Returns `false` without presenting anything when the app can't show a sheet right now (backgrounded, or nothing to present from). `ForumsClient` only calls this for one challenge at a time.
    func resolve(_ challenge: CloudflareChallenge) async -> Bool {
        guard UIApplication.shared.applicationState != .background else {
            logger.info("app is in the background; not presenting challenge")
            return false
        }
        guard let presenter = await window()?.sheetHostViewController() else {
            logger.warning("nowhere to present the challenge from")
            return false
        }

        // A solved challenge reloads whatever we loaded as a GET, so a POST's URL (a reply, a login) isn't worth revisiting; the front page earns the same zone-wide clearance.
        let loadURL = challenge.requestMethod == "GET" ? challenge.url : (ForumsClient.shared.baseURL ?? challenge.url)

        return await withCheckedContinuation { continuation in
            let viewController = CloudflareChallengeViewController(challenge: challenge, loadURL: loadURL) { cleared in
                continuation.resume(returning: cleared)
            }
            let nav = viewController.enclosingNavigationController
            nav.modalPresentationStyle = .pageSheet
            nav.sheetPresentationController?.detents = [.large()]
            presenter.present(nav, animated: true)
        }
    }
}
