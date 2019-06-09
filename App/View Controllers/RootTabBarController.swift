//  RootTabBarController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A themeable tab bar controller that fixes an iOS 11 layout problem.
final class RootTabBarController: UITabBarController, Themeable {

    /// Returns a tab bar controller whose tab bar is an instance of `TabBar_FixiOS11iPadLayout`.
    static func makeWithTabBarFixedForiOS11iPadLayout() -> RootTabBarController {
        let storyboard = UIStoryboard(name: "RootTabBarController", bundle: Bundle(for: RootTabBarController.self))
        guard let tabBarController = storyboard.instantiateInitialViewController() as? RootTabBarController else {
            fatalError("initial view controller in RootTabBarController.storyboard should be a RootTabBarController")
        }
        return tabBarController
    }

    /// Use `makeWithTabBarFixedForiOS11iPadLayout()` instead.
    private override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var tabBar: RootTabBar {
        return super.tabBar as! RootTabBar
    }

    var theme: Theme {
        return Theme.defaultTheme()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }

    func themeDidChange() {
        tabBar.barTintColor = theme["tabBarBackgroundColor"]
        tabBar.isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true
        tabBar.tintColor = theme["tintColor"]
        tabBar.topBorderColor = theme["bottomBarTopBorderColor"]
    }
}

/**
 A tab bar that fixes some issues we've come across. Some fixes are specific to Awful's particular use of the tab bar, so this may not be suitable as a general-purpose fix-it subclass.

 On iOS 11, `UITabBar` lays out its items with title and icon stacked horizontally whenever we're in a horizontally regular size class, and it does not do well if we constrict its width. Everything falls apart when the tab bar is in the primary view controller of a split view controller. This subclass overrides `traitCollection` and forces an always compact horizontal size class.

 On iOS 12, `UITabBar` has a hard time with safe area insets and can completely mess up its own layout after some combination of `hidesBottomBarOnPush` and/or full-screen modal presentation. The layout mess usually fixes itself after the pop animation that results in the tab bar appearing. This subclass overrides `sizeThatFits(_:)` and ensures that the returned height considers the safe area insets.

 Hilariously, the most reasonable way to convince a `UITabBarController` to use a custom `UITabBar` subclass is in a storyboard, so we use `RootTabBarController.storyboard`.

 - Seealso: `RootTabBarController.makeWithTabBarFixedForiOS11iPadLayout()`
 - Seealso: https://github.com/Awful/Awful.app/issues/357 where we were trying to puzzle this out.
 - Seealso: https://stackoverflow.com/a/45945937 which has this subclassing solution.
 - Seealso: https://github.com/bnickel/HidingTabBar which mentions that storyboard is the only reasonable way to crowbar a `UITabBar` subclass into a `UITabBarController`.
 - Seealso: https://stackoverflow.com/a/53524635 which overrides `sizeThatFits(_:)` to force safe area consideration.
 - Seealso: `UITabBar+FixiOS12_1Layout.h` which addresses another UITabBar issue in iOS 12.
 */
final class RootTabBar: UITabBar {

    private lazy var topBorder: HairlineView = {
        let topBorder = HairlineView()
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder, constrainEdges: [.top, .left, .right])
        return topBorder
    }()

    var topBorderColor: UIColor? {
        get { return topBorder.backgroundColor }
        set { topBorder.backgroundColor = newValue }
    }

    override var traitCollection: UITraitCollection {
        return UITraitCollection(traitsFrom: [
            super.traitCollection,
            UITraitCollection(horizontalSizeClass: .compact)])
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = super.sizeThatFits(size)
        if #available(iOS 11.0, *) {
            let bottomInset = safeAreaInsets.bottom
            if size.height - bottomInset < 40 {
                size.height += bottomInset
            }
        }
        return size
    }
}
