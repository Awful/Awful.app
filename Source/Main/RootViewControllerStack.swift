//  RootViewControllerStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// The RootViewControllerStack initializes the logged-in root view controller, implements releated delegate methods, and handles state restoration.
class RootViewControllerStack: NSObject, UISplitViewControllerDelegate {
    
    let managedObjectContext: NSManagedObjectContext
    
    var rootViewController: UIViewController {
        get { return splitViewController }
    }
    
    private let splitViewController: UISplitViewController
    private let tabBarController: UITabBarController
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        splitViewController = UISplitViewController()
        tabBarController = UITabBarController()
        super.init()
        
        let forums = ForumListViewController(managedObjectContext: managedObjectContext)
        forums.restorationIdentifier = "Forum list"
        
        let bookmarks = BookmarkedThreadListViewController(managedObjectContext: managedObjectContext)
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
        
        splitViewController.viewControllers = [tabBarController, emptyNavigationController]
        splitViewController.delegate = self
        splitViewController.restorationIdentifier = "Root splitview"
        splitViewController.maximumPrimaryColumnWidth = 350
        splitViewController.preferredPrimaryColumnWidthFraction = 0.5
        
        updateMessagesTabPresence()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "settingsDidChange:", name: AwfulSettingsDidChangeNotification, object: nil)
        
        configureSplitViewControllerDisplayMode()
		configureTabBarColor()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    private func createEmptyDetailNavigationController() -> UINavigationController {
        let emptyNavigationController = EmptyViewController().enclosingNavigationController
        emptyNavigationController.restorationIdentifier = navigationIdentifier("Detail")
        emptyNavigationController.restorationClass = nil
        return emptyNavigationController
    }
    
    private func updateMessagesTabPresence() {
        let roots = tabBarController.mutableArrayValueForKey("viewControllers")
        let messagesRestorationIdentifier = "Messages"
        var messagesTabIndex: Int?
        for (i, root) in enumerate(roots) {
            let navigationController = root as UINavigationController
            let viewController = navigationController.viewControllers[0] as UIViewController
            if viewController.restorationIdentifier == messagesRestorationIdentifier {
                messagesTabIndex = i
                break
            }
        }
        
        if AwfulSettings.sharedSettings().canSendPrivateMessages {
            if messagesTabIndex == nil {
                let messages = MessageListViewController(managedObjectContext: managedObjectContext)
                messages.restorationIdentifier = messagesRestorationIdentifier
                let navigationController = messages.enclosingNavigationController
                navigationController.restorationIdentifier = navigationIdentifier(messages.restorationIdentifier)
                navigationController.restorationClass = nil
                roots.insertObject(navigationController, atIndex: 2)
            }
        } else {
            if let messagesTabIndex = messagesTabIndex {
                roots.removeObjectAtIndex(messagesTabIndex)
            }
        }
    }
    
    @objc private func settingsDidChange(notification: NSNotification) {
        let userInfo = notification.userInfo as [String:String]
        let changeKey = userInfo[AwfulSettingsDidChangeSettingKey]!
        if changeKey == AwfulSettingsKeys.canSendPrivateMessages {
            updateMessagesTabPresence()
        } else if changeKey == AwfulSettingsKeys.hideSidebarInLandscape {
            configureSplitViewControllerDisplayMode()
		} else if changeKey == AwfulSettingsKeys.darkTheme {
			configureTabBarColor()
		}
    }
	
	private func configureTabBarColor() {
		if AwfulSettings.sharedSettings().darkTheme {
			self.tabBarController.tabBar.barTintColor = UIColor.blackColor()
		} else {
			//
			self.tabBarController.tabBar.barTintColor = nil
		}
		self.tabBarController.tabBar.tintColor = UIColor(red: 0.078, green: 0.514, blue: 0.694, alpha: 1.0)
	}
	
    private func configureSplitViewControllerDisplayMode() {
        if AwfulSettings.sharedSettings().hideSidebarInLandscape {
            if splitViewController.displayMode == .PrimaryOverlay {
                splitViewController.preferredDisplayMode = .PrimaryOverlay
            } else {
                splitViewController.preferredDisplayMode = .PrimaryHidden
            }
        } else {
            splitViewController.preferredDisplayMode = .Automatic
        }
    }

    func viewControllerWithRestorationIdentifierPath(identifierComponents: [String]) -> UIViewController? {

        // I can't recursively call a nested function? Toss it in a closure then I guess.
        var search: ([String], [UIViewController]) -> UIViewController? = { _, _ in nil }
        search = { identifierComponents, viewControllers in
            if let i = find(viewControllers.map({ $0.restorationIdentifier ?? "" }), identifierComponents[0]) {
                let currentViewController = viewControllers[i]
                if identifierComponents.count == 1 {
                    return currentViewController
                } else if currentViewController.respondsToSelector("viewControllers") {

                    // dropFirst(identifierComponents) did weird stuff here, so I guess let's turn up the awkwardness.
                    let remainingPath = identifierComponents[1..<identifierComponents.count]
                    let subsequentViewControllers = currentViewController.valueForKey("viewControllers") as [UIViewController]
                    return search(Array(remainingPath), subsequentViewControllers)
                }
            }
            return nil
        }
        return search(identifierComponents, [splitViewController])
    }

    func didAppear() {
        if let detailNavigationController = detailNavigationController {

            // Our UISplitViewControllerDelegate methods get called *before* we're done restoring state, so the "show sidebar" button item doesn't get put in place properly. Fix that here.
            if splitViewController.displayMode != .AllVisible {
                let detailViewController = detailNavigationController.viewControllers[0] as UIViewController
                detailViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
            }
        }
    }
    
    private var primaryNavigationController: UINavigationController {
        get { return tabBarController.selectedViewController as UINavigationController }
    }

    private var detailNavigationController: UINavigationController? {
        get {
            let viewControllers = splitViewController.viewControllers as [UINavigationController]
            return viewControllers.count > 1 ? viewControllers[1] : nil
        }
    }
    
    // MARK: UISplitViewControllerDelegate
    
    func splitViewController(splitViewController: UISplitViewController!, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool {
        
        // We have no need for the empty view controller when collapsed.
        if secondaryViewController.awful_firstDescendantViewControllerOfClass(EmptyViewController.self) != nil {
            return true
        }
        
        let secondaryNavigationController = secondaryViewController as UINavigationController
        let combinedStack = primaryNavigationController.viewControllers + secondaryNavigationController.viewControllers
        primaryNavigationController.viewControllers = combinedStack
        return true
    }
    
    func splitViewController(splitViewController: UISplitViewController!, separateSecondaryViewControllerFromPrimaryViewController primaryViewController: UIViewController!) -> UIViewController! {
        let viewControllers = primaryNavigationController.viewControllers as [UIViewController]
        var secondaryViewControllers = Array(slice(viewControllers) { $0.prefersSecondaryViewController })
        let secondaryNavigationController = createEmptyDetailNavigationController()
        if !secondaryViewControllers.isEmpty {
            secondaryNavigationController.viewControllers = secondaryViewControllers
            let primaryViewControllers = Array(viewControllers[0 ..< viewControllers.count - secondaryViewControllers.count])
            primaryNavigationController.viewControllers = primaryViewControllers
        }

        // TODO bring along the swipe-from-right-edge-to-unpop stack too
        return secondaryNavigationController
    }

    func splitViewController(splitViewController: UISplitViewController!, showDetailViewController viewController: UIViewController!, sender: AnyObject!) -> Bool {
        if splitViewController.collapsed {
            primaryNavigationController.pushViewController(viewController, animated: true)
        } else {
            if splitViewController.displayMode != .AllVisible {
                viewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
            }

            self.detailNavigationController!.setViewControllers([viewController], animated: false)
            
            // Laying out the split view now prevents it from getting caught up in the animation block that hides the primary view controller. Otherwise we get to see an ugly animated resizing of the new secondary view from a 0-rect up to full screen.
            self.splitViewController.view.layoutIfNeeded()
            
            splitViewController.awful_hidePrimaryViewController()
        }

        return true
    }

    func splitViewController(splitViewController: UISplitViewController!, willChangeToDisplayMode displayMode: UISplitViewControllerDisplayMode) {
        let rootViewController = detailNavigationController!.viewControllers[0] as UIViewController
        if displayMode == .AllVisible {
            rootViewController.navigationItem.setLeftBarButtonItem(nil, animated: true)
        } else {
            rootViewController.navigationItem.setLeftBarButtonItem(splitViewController.displayModeButtonItem(), animated: true)
        }
    }
    
    // MARK: Initializer not meant to be called
    
    override init() {
        fatalError("RootViewControllerStack needs a managed object context")
    }
}

private func navigationIdentifier(rootIdentifier: String?) -> String {
    return "\(rootIdentifier) navigation"
}

func slice<S:Sliceable>(s: S, test: (S.Generator.Element) -> Bool) -> S.SubSlice {
    for i in s.startIndex ..< s.endIndex {
        if test(s[i]) {
            return s[i ..< s.endIndex]
        }
    }
    return s[s.endIndex ..< s.endIndex]
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
