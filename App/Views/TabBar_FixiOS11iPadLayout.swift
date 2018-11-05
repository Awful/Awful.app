//  TabBar_FixiOS11iPadLayout.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
 On iOS 11, `UITabBar` lays out its items with title and icon stacked horizontally whenever we're in a horizontally regular size class, and it does not do well if we constrict its width. Everything falls apart when the tab bar is in the primary view controller of a split view controller. So we subclass `UITabBar` here and override its trait collection.

 Hilariously, the most reasonable way to convince a `UITabBarController` to use a custom `UITabBar` subclass is in a storyboard. So we do that too.

 - Seealso: `UITabBarController.makeWithTabBarFixedForiOS11iPadLayout()`
 - Seealso: https://github.com/Awful/Awful.app/issues/357 where we were trying to puzzle this out.
 - Seealso: https://stackoverflow.com/a/45945937/1063051 which has this subclassing solution.
 - Seealso: https://github.com/bnickel/HidingTabBar which mentions that storyboard is the only reasonable way to crowbar a `UITabBar` subclass into a `UITabBarController`.
 */
final class TabBar_FixiOS11iPadLayout: UITabBar {
    override var traitCollection: UITraitCollection {
        return UITraitCollection(traitsFrom: [
            super.traitCollection,
            UITraitCollection(horizontalSizeClass: .compact)])
    }
}

extension UITabBarController {

    /// Returns a tab bar controller whose tab bar is an instance of `TabBar_FixiOS11iPadLayout`.
    static func makeWithTabBarFixedForiOS11iPadLayout() -> UITabBarController {
        let storyboard = UIStoryboard(name: "TabBarController_FixiOS11iPadLayout", bundle: Bundle(for: TabBar_FixiOS11iPadLayout.self))
        guard let tabBarController = storyboard.instantiateInitialViewController() as? UITabBarController else {
            fatalError("initial view controller in TabBarController_FixiOS11iPadLayout.storyboard should be a UITabBarController")
        }
        return tabBarController
    }
}
