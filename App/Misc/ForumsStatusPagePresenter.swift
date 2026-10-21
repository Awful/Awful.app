//  ForumsStatusPagePresenter.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsStatusPagePresenter")

/// Puts a `ForumsStatusPageViewController` on screen over whatever the user is looking at, and reports when they've closed it. Wired up as `ForumsClient.forumsUnavailableHandler`.
@MainActor
final class ForumsStatusPagePresenter {

    private let window: () -> UIWindow?

    init(window: @escaping () -> UIWindow?) {
        self.window = window
    }

    /// Presents the status page and waits for the user to close it. Returns `false` without presenting anything when the app can't show a sheet right now (backgrounded, or nothing to present from). `ForumsClient` only calls this for one outage at a time.
    func present(statusPageURL: URL) async -> Bool {
        guard UIApplication.shared.applicationState != .background else {
            logger.info("app is in the background; not presenting status page")
            return false
        }
        guard let presenter = await window()?.sheetHostViewController() else {
            logger.warning("nowhere to present the status page from")
            return false
        }

        return await withCheckedContinuation { continuation in
            let viewController = ForumsStatusPageViewController(statusPageURL: statusPageURL) {
                continuation.resume(returning: true)
            }
            let nav = viewController.enclosingNavigationController
            nav.modalPresentationStyle = .pageSheet
            nav.sheetPresentationController?.detents = [.large()]
            nav.presentationController?.delegate = viewController
            presenter.present(nav, animated: true)
        }
    }
}
