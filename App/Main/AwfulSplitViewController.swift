//  AwfulSplitViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Forwards status bar style questions to its first view controller; tells delegate when split view controller will transition to a new size.
class AwfulSplitViewController: UISplitViewController {
    override var childForStatusBarStyle : UIViewController? {
        return viewControllers.first as UIViewController?
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        let delegate = self.delegate as? AwfulSplitViewControllerDelegate
        delegate?.splitView(self, viewWillTransitionToSize: size, with: coordinator)
    }
}

protocol AwfulSplitViewControllerDelegate: UISplitViewControllerDelegate {
    func splitView(
        _ splitView: AwfulSplitViewController,
        viewWillTransitionToSize size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    )
}
