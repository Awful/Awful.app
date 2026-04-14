//  RootViewControllerStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import Combine
import CoreData
import UIKit

/// The RootViewControllerStack initializes the logged-in root view controller and implements related delegate methods.
final class RootViewControllerStack: NSObject, AwfulSplitViewControllerDelegate {
    
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorage(Settings.hideSidebarInLandscape) private var hideSidebarInLandscape
    let managedObjectContext: NSManagedObjectContext
    private var notifiers: [NSObjectProtocol] = []
    
    lazy private(set) var rootViewController: UIViewController = {
        // This was a fun one! If you change the app icon (using `UIApplication.setAlternateIconName(…)`), the alert it presents causes `UISplitViewController` to dismiss its primary view controller. Even on a phone when there is no secondary view controller. The fix? It seems like the alert is presented on the current `rootViewController`, so if that isn't the split view controller then we're all set!
        let container = PassthroughViewController()
        container.userInterfaceStyleDidChange = { [weak self] in self?.userInterfaceStyleDidChange() }
        container.addChild(self.splitViewController)
        self.splitViewController.view.frame = CGRect(origin: .zero, size: container.view.bounds.size)
        self.splitViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.view.addSubview(self.splitViewController.view)
        self.splitViewController.didMove(toParent: container)
        return container
    }()
    
    private let splitViewController: AwfulSplitViewController
    private let tabBarController: UITabBarController

    var userInterfaceStyleDidChange: () -> Void = {}
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        splitViewController = AwfulSplitViewController()
        tabBarController = RootTabBarController.makeWithTabBarFixedForiOS11iPadLayout()
        super.init()
        
        let forums = ForumsTableViewController(managedObjectContext: managedObjectContext)
        let bookmarks = BookmarksTableViewController(managedObjectContext: managedObjectContext)
        let lepers = RapSheetViewController()
        let settings = SettingsViewController(managedObjectContext: managedObjectContext)

        tabBarController.viewControllers = [forums, bookmarks, lepers, settings].map { $0.enclosingNavigationController }

        let emptyNavigationController = createEmptyDetailNavigationController()
        emptyNavigationController.pushViewController(EmptyViewController(), animated: false)

        splitViewController.viewControllers = [tabBarController, emptyNavigationController]
        splitViewController.delegate = self
        splitViewController.maximumPrimaryColumnWidth = 350
        splitViewController.preferredPrimaryColumnWidthFraction = 0.5

        updateMessagesTabPresence()
        
        $hideSidebarInLandscape
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.configureSplitViewControllerDisplayMode() }
            .store(in: &cancellables)

        $canSendPrivateMessages
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMessagesTabPresence() }
            .store(in: &cancellables)

        configureSplitViewControllerDisplayMode()
    }

    private func createEmptyDetailNavigationController() -> UINavigationController {
        return NavigationController()
    }

    private func updateMessagesTabPresence() {
        let roots = tabBarController.mutableArrayValue(forKey: "viewControllers")
        let messagesTabIndex = roots.indexOfObject(passingTest: { root, _, _ in
            (root as? UINavigationController)?.viewControllers.first is MessageListViewController
        })

        if canSendPrivateMessages {
            if messagesTabIndex == NSNotFound {
                let messages = MessageListViewController(managedObjectContext: managedObjectContext)
                roots.insert(messages.enclosingNavigationController, at: 2)
            }
        } else if messagesTabIndex != NSNotFound {
            roots.removeObject(at: messagesTabIndex)
        }
    }
	
    private func configureSplitViewControllerDisplayMode() {
        if hideSidebarInLandscape {
            switch splitViewController.displayMode {
            case .primaryOverlay, .allVisible:
                splitViewController.preferredDisplayMode = .oneOverSecondary
            case .primaryHidden:
                splitViewController.preferredDisplayMode = .secondaryOnly
            default:
                fatalError("unexpected display mode \(splitViewController.displayMode)")
            }
        } else {
            splitViewController.preferredDisplayMode = .automatic
        }
    }

    func didAppear() {
        // Believe me, it occurs to me that this is highly suspicious and probably indicates misuse of the split view controller. I would happily welcome corrected impressions and/or simplification suggestions. This is ugly.

        // I can't seem to get the iPhone 6+ to open in landscape to a primary overlay display mode. This makes that happen.
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()

        // Sometimes after restoring scene state the split view decides to get the wrong display mode, possibly through some combination of preserving in one orientation then restoring in another and the "Hide sidebar in landscape" setting (set to NO in both cases).
        let isPortrait = splitViewController.view.frame.width < splitViewController.view.frame.height
        if !splitViewController.isCollapsed {
            if isPortrait && splitViewController.displayMode == .oneBesideSecondary {
                splitViewController.preferredDisplayMode = .secondaryOnly
            }

            if !isPortrait && splitViewController.displayMode == .secondaryOnly && splitViewController.preferredDisplayMode == .automatic {
                splitViewController.preferredDisplayMode = .oneBesideSecondary
                splitViewController.preferredDisplayMode = .automatic
            }
        }

        let updateLeftButtonItem = { [weak self] in
            guard let self = self else { return }
            if let detail = self.detailNavigationController?.viewControllers.first {
                if self.splitViewController.displayMode != .oneBesideSecondary {
                    detail.navigationItem.leftBarButtonItem = self.backBarButtonItem
                }
            }
        }
        updateLeftButtonItem()

        // Fix missing "show sidebar" button after backgrounding.
        // (When we enter the background, we can get sized to portrait and then landscape orientations for iOS to take snapshots. In the resulting calls to `viewWillTransitionToSize()`, we hide/show the "show sidebar" button. But when we come back to the foreground, we don't get a size transition, so the button's visibility is left in whichever state was the last snapshot we were sized for.)
        notifiers += [
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: UIApplication.shared,
                queue: .main, using: { notification in
                    updateLeftButtonItem()
            })
        ]
    }
    
    /// Route describing the deepest visible `RestorableLocation`, used by `SceneDelegate` to
    /// build the scene's `stateRestorationActivity`.
    var currentRestorationRoute: AwfulRoute? {
        firstVisibleViewController { ($0 as? RestorableLocation)?.restorationRoute }
    }

    /// Route identifying the currently selected sidebar tab's root VC. Saved by `SceneDelegate`
    /// so the sidebar tab is restored independently of whatever detail thread/message the
    /// primary route captured. On iPad/macOS the detail pane and the sidebar tab are
    /// orthogonal — the primary route records the detail, this records the tab.
    var currentSidebarTabRoute: AwfulRoute? {
        guard let rootNav = tabBarController.selectedViewController as? UINavigationController,
              let root = rootNav.viewControllers.first as? RestorableLocation
        else { return nil }
        return root.restorationRoute
    }

    /// Route for the deepest `RestorableLocation` pushed on top of the selected tab's root
    /// (e.g. `.forum(id:)` for a `ThreadsTableViewController` pushed under `ForumsTableViewController`).
    /// Saved by `SceneDelegate` so that cold-launch restoration rebuilds the mid-stack
    /// navigation depth — without this, restoring a thread detail would land the user back on
    /// the forum list instead of the specific forum's thread list they had drilled into.
    /// Returns nil when the primary nav has only the tab root (redundant with
    /// `currentSidebarTabRoute`).
    var currentPrimaryDeepRoute: AwfulRoute? {
        guard let nav = tabBarController.selectedViewController as? UINavigationController else { return nil }
        let stack = nav.viewControllers
        guard stack.count > 1 else { return nil }
        for vc in stack.reversed() {
            if vc === stack.first { break }
            if let route = (vc as? RestorableLocation)?.restorationRoute {
                return route
            }
        }
        return nil
    }

    /// Topmost visible `PostsPageViewController`, used by `SceneDelegate` to read the current
    /// scroll fraction and hidden-posts count when building the scene's restoration activity.
    var topPostsPageViewController: PostsPageViewController? {
        firstVisibleViewController { $0 as? PostsPageViewController }
    }

    /// Topmost visible `MessageViewController`, used by `SceneDelegate` to read the current
    /// scroll fraction when building the scene's restoration activity.
    var topMessageViewController: MessageViewController? {
        firstVisibleViewController { $0 as? MessageViewController }
    }

    /// The currently selected tab's `NavigationController`, used by `SceneDelegate` to save and
    /// restore its swipe-from-right-edge unpop stack.
    var currentPrimaryNavigationController: NavigationController? {
        primaryNavigationController as? NavigationController
    }

    private func firstVisibleViewController<T>(matching transform: (UIViewController) -> T?) -> T? {
        let navs: [UINavigationController]
        if splitViewController.isCollapsed {
            navs = [primaryNavigationController]
        } else {
            navs = [detailNavigationController, primaryNavigationController].compactMap { $0 }
        }
        for nav in navs {
            for vc in nav.viewControllers.reversed() {
                if let result = transform(vc) {
                    return result
                }
            }
        }
        return nil
    }

    private var primaryNavigationController: UINavigationController {
        return tabBarController.selectedViewController as! UINavigationController
    }

    private var detailNavigationController: UINavigationController? {
        let viewControllers = splitViewController.viewControllers as! [UINavigationController]
        return viewControllers.count > 1 ? viewControllers[1] : nil
    }
    
    override init() {
        fatalError("RootViewControllerStack needs a managed object context")
    }
}

extension RootViewControllerStack {
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()
        
        let secondaryNavigationController = secondaryViewController as! UINavigationController
        if let detail = secondaryNavigationController.viewControllers.first as UIViewController? {
            detail.navigationItem.leftBarButtonItem = nil
        }
        
        // We have no need for the empty view controller when collapsed.
        if secondaryViewController.firstDescendant(ofType: EmptyViewController.self) != nil {
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

    func splitViewController(
        _ splitViewController: UISplitViewController,
        separateSecondaryFrom primaryViewController: UIViewController
    ) -> UIViewController? {
        kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior()
        
        let viewControllers = primaryNavigationController.viewControllers 
        let (primaryStack, secondaryStack) = partition(viewControllers) { vc in
            guard let vc = vc as? HasSplitViewPreference else { return false }
            return vc.prefersSecondaryViewController
        }
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
    private func kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior() {
        let tempMode = splitViewController.preferredDisplayMode
        splitViewController.preferredDisplayMode = .automatic
        splitViewController.preferredDisplayMode = tempMode
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        showDetail viewController: UIViewController,
        sender: Any?
    ) -> Bool {
        if splitViewController.isCollapsed {
            primaryNavigationController.pushViewController(viewController, animated: true)
        } else {
            if splitViewController.displayMode != .oneBesideSecondary {
                viewController.navigationItem.leftBarButtonItem = backBarButtonItem
            }
            
            detailNavigationController!.setViewControllers([viewController], animated: false)
            
            // Laying out the split view now prevents it from getting caught up in the animation block that hides the primary view controller. Otherwise we get to see an ugly animated resizing of the new secondary view from a 0-rect up to full screen.
            splitViewController.view.layoutIfNeeded()
            
            splitViewController.hidePrimaryViewController()
        }
        
        return true
    }

    func splitView(
        _ splitView: AwfulSplitViewController,
        viewWillTransitionToSize size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil, completion: { context in
            // Make sure the "show sidebar" button item is in place after an interface rotation.
            // (We used to misuse the delegate method `targetDisplayModeForAction(in:)` to do this, but that sometimes resulted in an endless recursive call starting on iOS 13.)
            if
                let detailNav = self.detailNavigationController,
                let root = detailNav.viewControllers.first
            {
                let displayMode = self.splitViewController.displayMode
                root.navigationItem.leftBarButtonItem = displayMode == .oneBesideSecondary ? nil : self.backBarButtonItem
            }
        })
    }
    
    private var backBarButtonItem: UIBarButtonItem? {
        guard !splitViewController.isCollapsed else {
            return nil
        }

        let realItem = splitViewController.displayModeButtonItem
        // Don't set explicit tintColor — let Liquid Glass adapt the color
        // dynamically based on the content behind the detail nav bar.
        return UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: realItem.target, action: realItem.action)
    }
}

func partition<C: Collection>(_ c: C, test: (C.Iterator.Element) -> Bool) -> (C.SubSequence, C.SubSequence) {
    if let i = c.firstIndex(where: test) {
        return (c.prefix(upTo: i), c.suffix(from: i))
    }
    return (c.prefix(upTo: c.endIndex), c.suffix(from: c.endIndex))
}

protocol HasSplitViewPreference {
    var prefersSecondaryViewController: Bool { get }
}

extension PostsPageViewController: HasSplitViewPreference {
    var prefersSecondaryViewController: Bool {
        return true
    }
}

extension MessageViewController: HasSplitViewPreference {
    var prefersSecondaryViewController: Bool {
        return true
    }
}

private final class PassthroughViewController: UIViewController {

    var userInterfaceStyleDidChange: () -> Void = {}

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: PassthroughViewController, _: UITraitCollection) in
                self.userInterfaceStyleDidChange()
            }
        }
    }

    #if !targetEnvironment(macCatalyst)
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return children.first
    }
    #endif

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return children.first?.preferredStatusBarUpdateAnimation ?? super.preferredStatusBarUpdateAnimation
    }

    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return children.first
    }

    override var childForStatusBarHidden: UIViewController? {
        return children.first
    }

    override var childForStatusBarStyle: UIViewController? {
        return children.first
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return children.first?.preferredInterfaceOrientationForPresentation ?? super.preferredInterfaceOrientationForPresentation
    }

    override var shouldAutorotate: Bool {
        return children.first?.shouldAutorotate ?? super.shouldAutorotate
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return children.first?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #unavailable(iOS 17.0) {
            if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
                userInterfaceStyleDidChange()
            }
        }
    }
}
