//  RootTabBarController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A themeable tab bar controller that fixes layout issues on iOS 11 and 12.
final class RootTabBarController: UITabBarController {

    /// Returns a tab bar controller whose tab bar is an instance of `RootTabBar`.
    static func makeWithTabBarFixedForLayoutIssues() -> RootTabBarController {
        let storyboard = UIStoryboard(name: "RootTabBarController", bundle: Bundle(for: RootTabBarController.self))
        guard let tabBarController = storyboard.instantiateInitialViewController() as? RootTabBarController else {
            fatalError("initial view controller in RootTabBarController.storyboard should be a RootTabBarController")
        }
        return tabBarController
    }

    /// Use `makeWithTabBarFixedForLayoutIssues()` instead.
    private override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var tabBar: RootTabBar {
        return super.tabBar as! RootTabBar
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }
}

// MARK: - Themeable

extension RootTabBarController: Themeable {
    var theme: Theme { Theme.defaultTheme() }

    func themeDidChange() {
        tabBar.barTintColor = theme["tabBarBackgroundColor"]
        tabBar.isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true
        tabBar.tintColor = theme["tintColor"]
        tabBar.topBorderColor = theme["bottomBarTopBorderColor"]
    }
}

// MARK: - Tab bar

/**
 A tab bar that fixes a layout issue and adds a top border hairline view.

 This may be particular to Awful's use of the tab bar and is probably not suitable as a general-purpose fix-it subclass.

 On iOS 11 and 12, `UITabBar` has a hard time with safe area insets and can completely mess up its own layout after some combination of `hidesBottomBarOnPush` and/or full-screen modal presentation. The layout mess usually fixes itself after the pop animation that results in the tab bar appearing. This subclass overrides `sizeThatFits(_:)` and ensures that the returned height considers the safe area insets.

 Hilariously, the most reasonable way to convince a `UITabBarController` to use a custom `UITabBar` subclass is in a storyboard, so we use `RootTabBarController.storyboard`.

 - Seealso: `RootTabBarController.makeWithTabBarFixedForLayoutIssues()`
 - Seealso: https://github.com/Awful/Awful.app/issues/357 where we were trying to puzzle this out.
 - Seealso: https://stackoverflow.com/a/45945937 which has this subclassing solution.
 - Seealso: https://github.com/bnickel/HidingTabBar which mentions that storyboard is the only reasonable way to crowbar a `UITabBar` subclass into a `UITabBarController`.
 - Seealso: https://stackoverflow.com/a/53524635 which overrides `sizeThatFits(_:)` to force safe area consideration.
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

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = super.sizeThatFits(size)
        if #available(iOS 13.0, *) {
            return size
        }

        if #available(iOS 11.0, *) {
            let bottomInset = safeAreaInsets.bottom
            if size.height - bottomInset < 40 {
                size.height += bottomInset
            }
            return size
        }

        return size
    }
}
