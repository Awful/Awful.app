//  OneOrTwoPaneViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

private let Log = Logger.get()

/**
 A one- or two-pane view controller contains a split view controller with the logged-in user interface for the app.
 */
class OneOrTwoPaneViewController: UIViewController {

    private let managedObjectContext: NSManagedObjectContext
    private var observers: [NSKeyValueObservation] = []

    private lazy var splitVC = UISplitViewController()
    private lazy var tabBarVC = RootTabBarController.makeWithTabBarFixedForLayoutIssues()

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)

        let forums = ForumsTableViewController(managedObjectContext: managedObjectContext)
        forums.restorationIdentifier = "Forum list"

        let bookmarks = BookmarksTableViewController(managedObjectContext: managedObjectContext)
        bookmarks.restorationIdentifier = "Bookmarks"

        let messages = UserDefaults.standard.loggedInUserCanSendPrivateMessages ? makeMessagesViewController() : nil

        let lepers = RapSheetViewController()
        lepers.restorationIdentifier = "Leper's Colony"

        let settings = SettingsViewController(managedObjectContext: managedObjectContext)
        settings.restorationIdentifier = "Settings"

        tabBarVC.restorationIdentifier = "Tabbar"
        tabBarVC.viewControllers = [forums, bookmarks, messages, lepers, settings]
            .compactMap { $0 }
            .map { vc in
                let nav = vc.enclosingNavigationController

                // We always provide the instances, so we don't want UIKit to make them for us.
                nav.restorationClass = nil

                return nav
        }

        let emptyNav = makeSecondaryNavigationController()
        emptyNav.viewControllers = [EmptyViewController()]

        configureSplitViewControllerDisplayMode()
        splitVC.delegate = self
        splitVC.maximumPrimaryColumnWidth = 350
        splitVC.preferredPrimaryColumnWidthFraction = 0.5
        splitVC.restorationIdentifier = "Root splitview"
        splitVC.viewControllers = [tabBarVC, emptyNav]

        addChild(splitVC)
        view.addSubview(splitVC.view, constrainEdges: .all)
        splitVC.didMove(toParent: self)

        updateBackButtonItemInSecondaryViewController()

        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.hideSidebarInLandscape) { [weak self] defaults in
                self?.configureSplitViewControllerDisplayMode()
                self?.updateBackButtonItemInSecondaryViewController()
            }
            $0.observe(\.loggedInUserCanSendPrivateMessages) { [weak self] defaults in
                self?.updateMessagesTabPresence()
            }
        }
    }

    // MARK: Messages tab

    private func makeMessagesViewController() -> MessageListViewController {
        let messagesVC = MessageListViewController(managedObjectContext: managedObjectContext)
        messagesVC.restorationIdentifier = Messages.restorationIdentifier
        return messagesVC
    }

    private func updateMessagesTabPresence() {
        let messagesTabIndex = (tabBarVC.viewControllers ?? [])
            .firstIndex { vc in
                let nav = vc as? UINavigationController
                let root = nav?.viewControllers.first
                return root?.restorationIdentifier == Messages.restorationIdentifier
        }

        if UserDefaults.standard.loggedInUserCanSendPrivateMessages {
            if messagesTabIndex == nil {
                let messagesVC = makeMessagesViewController()
                let nav = messagesVC.enclosingNavigationController
                nav.restorationClass = nil
                tabBarVC.viewControllers?.insert(nav, at: 2)
            }
        } else {
            if let i = messagesTabIndex {
                tabBarVC.viewControllers?.remove(at: i)
            }
        }
    }

    private enum Messages {
        static let restorationIdentifier = "Messages"
    }

    // MARK: View lifecycle

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { context in
            self.updateBackButtonItemInSecondaryViewController()
        })
    }

    // MARK: State preseveration and restoration

    // No need to decode; we'll initialize as normal on launch.

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(children, forKey: StateKey.children)
    }

    private enum StateKey {
        static let children = "children"
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



// MARK: Split view controller

extension OneOrTwoPaneViewController {
    private func configureSplitViewControllerDisplayMode() {
        if UserDefaults.standard.hideSidebarInLandscape {
            switch splitVC.displayMode {
            case .primaryOverlay, .allVisible:
                splitVC.preferredDisplayMode = .primaryOverlay

            case .primaryHidden:
                splitVC.preferredDisplayMode = .primaryHidden

            case .automatic:
                Log.w("split view controller's displayMode was automatic, which the documentation says should never happen")

            @unknown default:
                Log.w("handle unknown split view controller display mode")
            }
        } else {
            splitVC.preferredDisplayMode = .automatic
        }
    }

    private func makeSecondaryNavigationController() -> UINavigationController {
        let secondaryNav = NavigationController()
        secondaryNav.restorationIdentifier = "Detail navigation"
        secondaryNav.restorationClass = nil
        return secondaryNav
    }

    private var shouldShowBackButtonInSecondaryViewController: Bool {
        if splitVC.isCollapsed {
            return false
        }

        guard let view = viewIfLoaded else {
            return true
        }

        if view.bounds.width > view.bounds.height {
            return UserDefaults.standard.hideSidebarInLandscape
        } else {
            return true
        }
    }

    private func updateBackButtonItemInSecondaryViewController() {
        let secondaryNav = splitVC.viewControllers.dropFirst().first as? UINavigationController
        let secondaryVC = secondaryNav?.viewControllers.first
        if shouldShowBackButtonInSecondaryViewController {
            if !(secondaryVC?.navigationItem.leftBarButtonItem is ShowPrimaryBarButtonItem) {
                secondaryVC?.navigationItem.leftBarButtonItem = ShowPrimaryBarButtonItem(splitViewController: splitVC)
            }
        } else {
            secondaryVC?.navigationItem.leftBarButtonItem = nil
        }
    }

    private class ShowPrimaryBarButtonItem: UIBarButtonItem {
        convenience init(splitViewController: UISplitViewController) {
            let realItem = splitViewController.displayModeButtonItem
            self.init(image: UIImage(named: "back"), style: .plain, target: realItem.target, action: realItem.action)
        }
    }
}

extension OneOrTwoPaneViewController: UISplitViewControllerDelegate {
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController)
        -> Bool
    {
        let secondaryNav = secondaryViewController as! UINavigationController

        if secondaryNav.viewControllers.first is EmptyViewController {
            return true
        }

        let primaryTabController = primaryViewController as! UITabBarController
        let primaryNav = primaryTabController.selectedViewController as! UINavigationController

        // Setting a navigation controller's `viewControllers` property bypasses our unpop machinery and weird things happen with navigation items. For now we'll insert a dummy view controller so we can pop all the things we care about off the navigation stack, then we'll push each one in turn.
        let popped = secondaryNav.viewControllers
        secondaryNav.viewControllers.insert(UIViewController(), at: 0)
        for _ in popped {
            secondaryNav.popViewController(animated: false)
        }

        if popped.first?.navigationItem.leftBarButtonItem is ShowPrimaryBarButtonItem {
            popped.first?.navigationItem.leftBarButtonItem = nil
        }

        for vc in popped {
            primaryNav.pushViewController(vc, animated: false)
        }

        return true
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        separateSecondaryFrom primaryViewController: UIViewController)
        -> UIViewController?
    {
        let primaryTabController = primaryViewController as! UITabBarController
        let primaryNav = primaryTabController.selectedViewController as! UINavigationController

        let i = primaryNav.viewControllers.firstIndex {
            $0 is MessageViewController || $0 is PostsPageViewController
        } ?? primaryNav.viewControllers.endIndex

        let secondaries = primaryNav.viewControllers[i...]

        // Setting `primaryNav.viewControllers = …` bypasses our unpop machinery and weird things happen with navigation items. For now we'll just pop the right number of times.
        for _ in secondaries {
            primaryNav.popViewController(animated: false)
        }

        let secondaryNav = NavigationController()
        secondaryNav.restorationClass = nil
        secondaryNav.restorationIdentifier = "Detail navigation"
        if secondaries.isEmpty {
            secondaryNav.pushViewController(EmptyViewController(), animated: false)
        } else {
            for vc in secondaries {
                // Need to push each so the unpop handler builds up.
                secondaryNav.pushViewController(vc, animated: false)
            }
        }

        let secondaryVC = secondaryNav.viewControllers.first
        secondaryVC?.navigationItem.leftBarButtonItem = UserDefaults.standard.hideSidebarInLandscape ? ShowPrimaryBarButtonItem(splitViewController: splitViewController) : nil

        return secondaryNav
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        showDetail detailViewController: UIViewController,
        sender: Any?)
        -> Bool
    {
        if splitViewController.isCollapsed {
            let selectedNav = tabBarVC.selectedViewController as! UINavigationController
            selectedNav.pushViewController(detailViewController, animated: true)
            return true
        } else {
            detailViewController.navigationItem.leftBarButtonItem = ShowPrimaryBarButtonItem(splitViewController: splitViewController)
            let detailNav = splitViewController.viewControllers[1] as! UINavigationController
            detailNav.viewControllers = [detailViewController]

            splitViewController.hidePrimaryViewController()

            return true
        }
    }
}
