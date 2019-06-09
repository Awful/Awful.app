//  AwfulSplitViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Forwards status bar style questions to its first view controller.
class AwfulSplitViewController: UISplitViewController {
    override var childForStatusBarStyle : UIViewController? {
        return viewControllers.first as UIViewController?
    }
}
