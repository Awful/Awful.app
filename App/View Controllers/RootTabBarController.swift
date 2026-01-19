//  RootTabBarController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import UIKit

/// A themeable tab bar controller.
final class RootTabBarController: UITabBarController, UITabBarControllerDelegate, Themeable {

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics

    static func makeWithTabBarFixedForiOS11iPadLayout() -> RootTabBarController {
        return RootTabBarController(nibName: nil, bundle: nil)
    }

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        delegate = self
#if targetEnvironment(macCatalyst)
        if #available(macCatalyst 18.0, *) {
            mode = .tabSidebar
        }
#endif
    }

    private var customTabBar: RootTabBar? {
        return super.tabBar as? RootTabBar
    }

    var theme: Theme {
        return Theme.defaultTheme()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }

    // called whenever a tab button is tapped
     func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
     ) {
         if enableHaptics {
             UIImpactFeedbackGenerator(style: .medium).impactOccurred()
         }
     }
        
    func themeDidChange() {
        tabBar.barTintColor = theme["tabBarBackgroundColor"]
        tabBar.isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true
        tabBar.tintColor = theme["tintColor"]
        customTabBar?.topBorderColor = theme["bottomBarTopBorderColor"]
        
        let barAppearance = UITabBarAppearance()
        if tabBar.isTranslucent {
            barAppearance.configureWithDefaultBackground()
        } else {
            barAppearance.configureWithOpaqueBackground()
        }
        barAppearance.backgroundColor = Theme.defaultTheme()["backgroundColor"]!
        barAppearance.shadowImage = nil
        barAppearance.shadowColor = nil
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = Theme.defaultTheme()["tabBarIconSelectedColor"]!
        itemAppearance.normal.iconColor = Theme.defaultTheme()["tabBarIconNormalColor"]!

        barAppearance.inlineLayoutAppearance = itemAppearance
        barAppearance.stackedLayoutAppearance = itemAppearance
        barAppearance.compactInlineLayoutAppearance = itemAppearance

        tabBar.standardAppearance = barAppearance
        tabBar.scrollEdgeAppearance = barAppearance
    }
}

/**
 A tab bar that fixes layout issues with safe area insets.

 On iOS 12, `UITabBar` has a hard time with safe area insets and can completely mess up its own layout after some combination of `hidesBottomBarOnPush` and/or full-screen modal presentation. The layout mess usually fixes itself after the pop animation that results in the tab bar appearing. This subclass overrides `sizeThatFits(_:)` and ensures that the returned height considers the safe area insets.

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
        let bottomInset = safeAreaInsets.bottom
        if size.height - bottomInset < 40 {
            size.height += bottomInset
        }
        return size
    }
}
