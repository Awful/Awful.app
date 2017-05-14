//  RootViewControllerStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

/// The RootViewControllerStack initializes the logged-in root view controller, implements releated delegate methods, and handles state restoration.
class RootViewControllerStack: NSObject, UISplitViewControllerDelegate {
    
    let managedObjectContext: NSManagedObjectContext
    
    var rootViewController: UIViewController {
        get { return splitViewController }
    }
    
    fileprivate let splitViewController: AwfulSplitViewController
    fileprivate let tabBarController: UITabBarController
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        splitViewController = AwfulSplitViewController()
        tabBarController = UITabBarController()
        super.init()
        
        let forums = ForumsTableViewController(managedObjectContext: managedObjectContext)
        forums.restorationIdentifier = "Forum list"
        
        let bookmarks = BookmarksTableViewController(managedObjectContext: managedObjectContext)
        bookmarks.restorationIdentifier = "Bookmarks"
        
        let lepers = RapSheetViewController()
        lepers.restorationIdentifier = "Leper's Colony"
        
        let settings = SettingsViewController(managedObjectContext: managedObjectContext)
        settings.restorationIdentifier = "Settings"
        
        tabBarController.restorationIdentifier = "Tabbar"
        tabBarController.viewControllers = [forums, bookmarks, lepers, settings].map() {
            let navigationController = $0.enclosingNavigationController
            
            // We want the root navigation controllers to preserve their state, but we want to provide the restored instance ourselves.
            navigationController.restorationClass = nil
            navigationController.restorationIdentifier = navigationIdentifier($0.restorationIdentifier)
            
            return navigationController
        }
        
        let emptyNavigationController = createEmptyDetailNavigationController()
        emptyNavigationController.pushViewController(EmptyViewController(), animated: false)
        
        splitViewController.viewControllers = [tabBarController, emptyNavigationController]
        splitViewController.delegate = self
        splitViewController.restorationIdentifier = "Root splitview"
        splitViewController.maximumPrimaryColumnWidth = 350
        splitViewController.preferredPrimaryColumnWidthFraction = 0.5
        
        updateMessagesTabPresence()
        NotificationCenter.default.addObserver(self, selector: #selector(RootViewControllerStack.settingsDidChange(_:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
        
        configureSplitViewControllerDisplayMode()
		configureTabBarColor()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    fileprivate func createEmptyDetailNavigationController() -> UINavigationController {
        let emptyNavigationController = NavigationController()
        emptyNavigationController.restorationIdentifier = navigationIdentifier("Detail")
        emptyNavigationController.restorationClass = nil
        return emptyNavigationController
    }
    
    fileprivate func updateMessagesTabPresence() {
        let roots = tabBarController.mutableArrayValue(forKey: "viewControllers")
        let messagesRestorationIdentifier = "Messages"
        var messagesTabIndex: Int?
        for (i, root) in roots.enumerated() {
            let navigationController = root as! UINavigationController
            let viewController = navigationController.viewControllers[0]
            if viewController.restorationIdentifier == messagesRestorationIdentifier {
                messagesTabIndex = i
                break
            }
        }
        
        if AwfulSettings.shared().canSendPrivateMessages {
            if messagesTabIndex == nil {
                let messages = MessageListViewController(managedObjectContext: managedObjectContext)
                messages.restorationIdentifier = messagesRestorationIdentifier
                let navigationController = messages.enclosingNavigationController
                navigationController.restorationIdentifier = navigationIdentifier(messages.restorationIdentifier)
                navigationController.restorationClass = nil
                roots.insert(navigationController, at: 2)
            }
        } else {
            if let messagesTabIndex = messagesTabIndex {
                roots.removeObject(at: messagesTabIndex)
            }
        }
    }
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        let userInfo = (notification).userInfo!
        let changeKey = userInfo[AwfulSettingsDidChangeSettingKey]! as! String
        if changeKey == AwfulSettingsKeys.canSendPrivateMessages.takeUnretainedValue() as String {
            updateMessagesTabPresence()
        } else if changeKey == AwfulSettingsKeys.hideSidebarInLandscape.takeUnretainedValue() as String {
            configureSplitViewControllerDisplayMode()
		} else if changeKey == AwfulSettingsKeys.darkTheme.takeUnretainedValue() as String || changeKey == AwfulSettingsKeys.alternateTheme.takeUnretainedValue() as String {
			configureTabBarColor()
		}
    }
	
	fileprivate func configureTabBarColor() {
		if AwfulSettings.shared().darkTheme {
			self.tabBarController.tabBar.barTintColor = UIColor.black
		} else {
			self.tabBarController.tabBar.barTintColor = nil
		}
        
        if AwfulSettings.shared().alternateTheme {
            self.tabBarController.tabBar.tintColor = UIColor(red: 0.0, green: 0.275, blue: 0.588, alpha: 1.0)
        } else {
            self.tabBarController.tabBar.tintColor = UIColor(red: 0.078, green: 0.514, blue: 0.694, alpha: 1.0)

        }
        
	}
	
    fileprivate func configureSplitViewControllerDisplayMode() {
        if AwfulSettings.shared().hideSidebarInLandscape {
            switch splitViewController.displayMode {
            case .primaryOverlay, .allVisible:
                splitViewController.preferredDisplayMode = .primaryOverlay
            case .primaryHidden:
                splitViewController.preferredDisplayMode = .primaryHidden
            default:
                fatalError("unexpected display mode \(splitViewController.displayMode)")
            }
        } else {
            splitViewController.preferredDisplayMode = .automatic
        }
    }

    func viewControllerWithRestorationIdentifierPath(_ identifierComponents: [String]) -> UIViewController? {
        // I can't recursively call a nested function? Toss it in a closure then I guess.
        var search: ([String], [UIViewController]) -> UIViewController? = { _, _ in nil }
        search = { identifierComponents, viewControllers in
            if let i = viewControllers.map({ $0.restorationIdentifier ?? "" }).index(of: identifierComponents[0]) {
                let currentViewController = viewControllers[i]
                if identifierComponents.count == 1 {
                    return currentViewController
                } else if currentViewController.responds(to: #selector(getter: UINavigationController.viewControllers)) {
                    // dropFirst(identifierComponents) did weird stuff here, so I guess let's turn up the awkwardness.
                    let remainingPath = identifierComponents[1..<identifierComponents.count]
                    let subsequentViewControllers = currentViewController.value(forKey: "viewControllers") as! [UIViewController]
                    return search(Array(remainingPath), subsequentViewControllers)
                }
            }
            return nil
        }
        return search(identifierComponents, [splitViewController])
    }

    func didAppear() {
        // Believe me, it occurs to me that this is highly suspicious and probably indicates misuse of the split view controller. I would happily welcome corrected impressions and/or simplification suggestions. This is ugly.
        
        // I can't seem to get the iPhone 6+ to open in landscape to a primary overlay display mode. This makes that happen.
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()
        
        // Sometimes after restoring state the split view decides to get the wrong display mode, possibly through some combination of state restoration goofiness (e.g. preserving in one orientation then restoring in another) and the "Hide sidebar in landscape" setting (set to NO in both cases).
        let isPortrait = splitViewController.view.frame.width < splitViewController.view.frame.height
        if !splitViewController.isCollapsed {
            // One possibility is restoring in portrait orientation with the sidebar always visible.
            if isPortrait && splitViewController.displayMode == .allVisible {
                splitViewController.preferredDisplayMode = .primaryHidden
            }
            
            // Another possibility is restoring in landscape orientation with the sidebar always hidden, and no button to show it.
            if !isPortrait && splitViewController.displayMode == .primaryHidden && splitViewController.preferredDisplayMode == .automatic {
                splitViewController.preferredDisplayMode = .allVisible
                splitViewController.preferredDisplayMode = .automatic
            }
        }
        
        if let detail = detailNavigationController?.viewControllers.first {
            // Our UISplitViewControllerDelegate methods get called *before* we're done restoring state, so the "show sidebar" button item doesn't get put in place properly. Fix that here.
            if splitViewController.displayMode != .allVisible {
                detail.navigationItem.leftBarButtonItem = backBarButtonItem
            }
        }
    }
    
    fileprivate var primaryNavigationController: UINavigationController {
        return tabBarController.selectedViewController as! UINavigationController
    }

    fileprivate var detailNavigationController: UINavigationController? {
        let viewControllers = splitViewController.viewControllers as! [UINavigationController]
        return viewControllers.count > 1 ? viewControllers[1] : nil
    }
    
    override init() {
        fatalError("RootViewControllerStack needs a managed object context")
    }
}

extension RootViewControllerStack {
    @objc(splitViewController:collapseSecondaryViewController:ontoPrimaryViewController:)
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()
        
        let secondaryNavigationController = secondaryViewController as! UINavigationController
        if let detail = secondaryNavigationController.viewControllers.first as UIViewController? {
            detail.navigationItem.leftBarButtonItem = nil
        }
        
        // We have no need for the empty view controller when collapsed.
        if secondaryViewController.firstDescendantOfType(EmptyViewController.self) != nil {
            return true
        }
        
        let combinedStack = primaryNavigationController.viewControllers + secondaryNavigationController.viewControllers
        secondaryNavigationController.viewControllers = []
        primaryNavigationController.viewControllers = combinedStack
        
        // This ugliness fixes the resulting navigation controller's toolbar appearing empty despite having the correct items. (i.e. none of the items' views are in the toolbar's view hierarchy.) Presumably if some fix is discovered for the grey screen mentioned atop kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior, I think this will be fixed too. Or at least it's worth testing out.
        let toolbar = primaryNavigationController.toolbar
        let items = toolbar?.items
        toolbar?.items = nil
        toolbar?.items = items
        
        return true
    }
    
    @objc(splitViewController:separateSecondaryViewControllerFromPrimaryViewController:)
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()
        
        let viewControllers = primaryNavigationController.viewControllers 
        let (primaryStack, secondaryStack) = partition(viewControllers) { $0.prefersSecondaryViewController }
        primaryNavigationController.viewControllers = Array(primaryStack)
        let secondaryNavigationController = createEmptyDetailNavigationController()
        if secondaryStack.isEmpty {
            secondaryNavigationController.pushViewController(EmptyViewController(), animated: false)
        } else {
            for vc in secondaryStack {
                secondaryNavigationController.pushViewController(vc, animated: false)
            }
        }
        
        if let detail = secondaryNavigationController.viewControllers.first {
            detail.navigationItem.leftBarButtonItem = backBarButtonItem
        }
        
        // TODO bring along the swipe-from-right-edge-to-unpop stack too
        return secondaryNavigationController
    }
    
    // Split view controllers really don't like it outside of .Automatic on iPhone 6+. This largely works around a bug whereby the screen just turns grey after rotating from landscape to portrait with "Hide sidebar in landscape" enabled. rdar://problem/18553183
    fileprivate func kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior() {
        let tempMode = splitViewController.preferredDisplayMode
        splitViewController.preferredDisplayMode = .automatic
        splitViewController.preferredDisplayMode = tempMode
    }
    
    @objc(splitViewController:showDetailViewController:sender:)
    func splitViewController(_ splitViewController: UISplitViewController, showDetail viewController: UIViewController, sender: Any?) -> Bool {
        if splitViewController.isCollapsed {
            primaryNavigationController.pushViewController(viewController, animated: true)
        } else {
            if splitViewController.displayMode != .allVisible {
                viewController.navigationItem.leftBarButtonItem = backBarButtonItem
            }
            
            detailNavigationController!.setViewControllers([viewController], animated: false)
            
            // Laying out the split view now prevents it from getting caught up in the animation block that hides the primary view controller. Otherwise we get to see an ugly animated resizing of the new secondary view from a 0-rect up to full screen.
            splitViewController.view.layoutIfNeeded()
            
            splitViewController.hidePrimaryViewController()
        }
        
        return true
    }
    
    @objc(targetDisplayModeForActionInSplitViewController:)
    func targetDisplayModeForAction(in splitViewController: UISplitViewController) -> UISplitViewControllerDisplayMode {
        // Misusing this delegate method to make sure the "show sidebar" button item is in place after an interface rotation.
        if let detailNav = detailNavigationController {
            if let root = detailNav.viewControllers.first {
                root.navigationItem.leftBarButtonItem = splitViewController.displayMode == .allVisible ? nil : backBarButtonItem
            }
        }
        return .automatic
    }
    
    fileprivate var backBarButtonItem: UIBarButtonItem? {
        guard !splitViewController.isCollapsed else {
            return nil
        }
        
        let realItem = splitViewController.displayModeButtonItem
        return UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: realItem.target, action: realItem.action)
    }
}

private func navigationIdentifier(_ rootIdentifier: String?) -> String {
    if let identifier = rootIdentifier {
        return "\(identifier) navigation"
    } else {
        return "Navigation"
    }
}

func partition<C: Collection>(_ c: C, test: (C.Iterator.Element) -> Bool) -> (C.SubSequence, C.SubSequence) {
    if let i = c.index(where: test) {
        return (c.prefix(upTo: i), c.suffix(from: i))
    }
    return (c.prefix(upTo: c.endIndex), c.suffix(from: c.endIndex))
}

extension UIViewController {
    var prefersSecondaryViewController: Bool {
        get { return false }
    }
}

extension PostsPageViewController {
    override var prefersSecondaryViewController: Bool {
        get { return true }
    }
}

extension MessageViewController {
    override var prefersSecondaryViewController: Bool {
        get { return true }
    }
}
