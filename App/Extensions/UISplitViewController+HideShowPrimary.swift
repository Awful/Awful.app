//  UISplitViewController+HideShowPrimary.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UISplitViewController {

    /// Animates the primary view controller into view if it is not already visible.
    func showPrimaryViewController() {
        if !isCollapsed, displayMode == .primaryHidden {
            performDisplayModeButton()
        }
    }

    /// Animates the primary view controller out of view if it is currently visible in an overlay.
    func hidePrimaryViewController() {
        if !isCollapsed, displayMode == .primaryOverlay {
            performDisplayModeButton()
        }
    }

    private func performDisplayModeButton() {
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
}
