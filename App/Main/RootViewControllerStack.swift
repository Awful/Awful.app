//  RootViewControllerStack.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulRapsheet
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

    /// True after the user deliberately dismisses the pinned sidebar (setting OFF, landscape),
    /// so it stays hidden — including across backgrounding — until they summon it again.
    private var userHidPinnedSidebar = false

    /// True while the split view is mid size transition (rotation, or the portrait/landscape
    /// snapshot resizes iOS performs on backgrounding), when display-mode changes are
    /// UIKit's doing rather than the user's.
    private var isTransitioningSize = false

    /// True while `performRestorationReplay` runs, so detail shows (which reach us through a
    /// delegate method with no `animated` parameter) happen without animation.
    private(set) var isReplayingRestoration = false

    /// Runs `body` with detail-column transitions unanimated, for scene-restoration replay.
    func performRestorationReplay(_ body: () -> Void) {
        isReplayingRestoration = true
        defer { isReplayingRestoration = false }
        body()
    }
    
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
        let lepers = RapSheetViewController(handlers: .awful)
        let settings = SettingsViewController(managedObjectContext: managedObjectContext)

        tabBarController.viewControllers = [forums, bookmarks, lepers, settings].map { $0.enclosingNavigationController }

        // Defeat UIKit's legacy auto-restoration of selectedIndex; scene-activity replay
        // is the only intended source of tab selection.
        tabBarController.restorationIdentifier = nil
        for case let nav as UINavigationController in tabBarController.viewControllers ?? [] {
            nav.restorationIdentifier = nil
            nav.viewControllers.first?.restorationIdentifier = nil
        }

        let emptyNavigationController = createEmptyDetailNavigationController()
        emptyNavigationController.pushViewController(EmptyViewController(), animated: false)

        splitViewController.viewControllers = [tabBarController, emptyNavigationController]
        splitViewController.delegate = self
        splitViewController.maximumPrimaryColumnWidth = 350
        splitViewController.preferredPrimaryColumnWidthFraction = 0.5
        if #available(iOS 26.0, *) {
            // The sidebar column stays flat (see NavigationController.hidesSharedBarButtonBackground),
            // but iOS 27 puts a glass platter behind the system sidebar toggle in that bar and
            // nothing reaches it (`displayModeButtonItem.hidesSharedBackground` has no effect). So
            // the sidebar nav controllers draw their own toggle, fed the display mode below, and
            // the system's is switched off the only way a classic-style split view allows
            // (`displayModeButtonVisibility` raises here). That also drops UIKit's toggle from
            // the detail column, so the detail nav controller draws its own there too (see
            // NavigationController.refreshDetailLeadingItems); and the edge swipe it drops
            // is covered by AwfulSplitViewController's own reveal pan.
            splitViewController.presentsWithGesture = false
        }

        updateMessagesTabPresence()

        (tabBarController as? RootTabBarController)?.onReselectTab = { [weak self] in self?.scrollTabToTop($0) }
        
        $hideSidebarInLandscape
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Flipping the setting starts the new mode from its default state.
                self?.userHidPinnedSidebar = false
                self?.configureSplitViewControllerDisplayMode()
            }
            .store(in: &cancellables)

        $canSendPrivateMessages
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMessagesTabPresence() }
            .store(in: &cancellables)

        configureSplitViewControllerDisplayMode()

        NotificationCenter.default.addObserver(self, selector: #selector(dataStoreDidReset), name: .dataStoreDidReset, object: nil)
    }

    /// Pushed detail view controllers (PostsPage, PrivateMessageView, Profile, etc.) and
    /// any presented modals hold references to managed objects from the now-deleted store.
    /// Unwind the UI to tab roots so rendering/interaction can't fault those dead objects.
    @objc private func dataStoreDidReset() {
        rootViewController.dismiss(animated: false)

        for tab in tabBarController.viewControllers ?? [] {
            (tab as? UINavigationController)?.popToRootViewController(animated: false)
        }

        if splitViewController.viewControllers.count > 1,
           let detailNav = splitViewController.viewControllers[1] as? UINavigationController {
            detailNav.popToRootViewController(animated: false)
        }
    }

    private func createEmptyDetailNavigationController() -> UINavigationController {
        return NavigationController()
    }

    private func updateMessagesTabPresence() {
        guard var roots = tabBarController.viewControllers else { return }
        let selected = tabBarController.selectedViewController
        let messagesTabIndex = roots.firstIndex {
            ($0 as? UINavigationController)?.viewControllers.first is MessageListViewController
        }

        if canSendPrivateMessages {
            guard messagesTabIndex == nil else { return }
            let messages = MessageListViewController(managedObjectContext: managedObjectContext)
            roots.insert(messages.enclosingNavigationController, at: 2)
        } else if let messagesTabIndex {
            roots.remove(at: messagesTabIndex)
        } else {
            return
        }

        // Restore the selection by object after mutating: `UITabBarController` keeps the
        // numeric `selectedIndex` across `setViewControllers(_:)`, and the Messages tab
        // lives mid-array, so an index-preserved selection would silently move the user
        // one tab over (onto Lepers, when Messages itself was selected and removed).
        tabBarController.setViewControllers(roots, animated: false)
        if let selected, roots.contains(selected) {
            tabBarController.selectedViewController = selected
        } else if selected != nil {
            // The selected Messages tab was removed; land on Forums rather than whatever
            // inherited its index.
            tabBarController.selectedIndex = 0
        }
    }
    
    private func configureSplitViewControllerDisplayMode() {
        let svc = splitViewController
        guard svc.isViewLoaded else {
            // Launch: nothing on screen yet. Start hidden when the setting is on; otherwise
            // let UIKit resolve the orientation-appropriate initial mode (initial .automatic
            // resolution works; it's only re-resolution after changes that's unreliable).
            svc.preferredDisplayMode = hideSidebarInLandscape ? .secondaryOnly : .automatic
            return
        }
        guard !svc.isCollapsed else { return }
        let isLandscape = svc.view.bounds.width > svc.view.bounds.height
        let sidebarIsVisible = [.oneOverSecondary, .oneBesideSecondary].contains(svc.displayMode)
        let target: UISplitViewController.DisplayMode
        if !hideSidebarInLandscape, isLandscape {
            // Pinned and always visible — unless the user deliberately dismissed it.
            target = userHidPinnedSidebar ? .secondaryOnly : .oneBesideSecondary
        } else if sidebarIsVisible {
            // Keep a visible sidebar on screen as an overlay (e.g. the user just toggled
            // the setting from the Settings tab, which lives in the sidebar); it hides on
            // selection or tap-out as usual.
            target = .oneOverSecondary
        } else {
            target = .secondaryOnly
        }
        guard svc.preferredDisplayMode != target else { return }
        UIView.animate(withDuration: 0.25) { svc.preferredDisplayMode = target }
    }

    /// Scene restoration is about to show a thread or message. Where showing it hides the
    /// sidebar anyway (portrait, or "Hide sidebar in landscape"), start hidden: otherwise the
    /// first layout resolves to the sidebar overlay, and it's on screen for the launch's first
    /// frames before the restored detail's hide takes effect.
    func hideSidebarForRestoredDetail(in size: CGSize) {
        let isLandscape = size.width > size.height
        guard !isLandscape || hideSidebarInLandscape else { return }
        splitViewController.preferredDisplayMode = .secondaryOnly
    }

    /// The tab roots' nav controllers, which draw the sidebar's own toggle on iOS 26+.
    private var sidebarNavigationControllers: [NavigationController] {
        (tabBarController.viewControllers ?? []).compactMap { $0 as? NavigationController }
    }

    /// Hands the split view's display mode to every nav controller that draws a sidebar toggle
    /// of its own: the sidebar columns (a "hide" toggle while the sidebar is visible) and the
    /// detail column (a "show" toggle on each of its screens while it isn't pinned). The live
    /// `displayMode` lags a change until its animation ends, so callers pass the mode being
    /// moved to where they know it.
    private func propagateSidebarDisplayMode(_ displayMode: UISplitViewController.DisplayMode) {
        for nav in sidebarNavigationControllers {
            nav.sidebarDisplayMode = displayMode
        }
        (detailNavigationController as? NavigationController)?.sidebarDisplayMode = displayMode
    }

    /// Re-syncs the columns' toggles with the split view's current mode where no delegate
    /// callback is coming: after appearing, foregrounding, or rotating.
    private func refreshSidebarToggles() {
        propagateSidebarDisplayMode(splitViewController.displayMode)
        (detailNavigationController as? NavigationController)?.refreshDetailLeadingItems()
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
        }
        refreshSidebarToggles()

        // Fix missing "show sidebar" button after backgrounding.
        // (When we enter the background, we can get sized to portrait and then landscape orientations for iOS to take snapshots. In the resulting calls to `viewWillTransitionToSize()`, we hide/show the "show sidebar" button. But when we come back to the foreground, we don't get a size transition, so the button's visibility is left in whichever state was the last snapshot we were sized for.)
        notifiers += [
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: UIApplication.shared,
                queue: .main, using: { [weak self] _ in
                    self?.refreshSidebarToggles()
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
            // When collapsed, the detail screens (thread, message) sit on this stack too. Skip
            // them: they're the primary route, and the depth to rebuild is what's beneath them.
            if (vc as? HasSplitViewPreference)?.prefersSecondaryViewController == true { continue }
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
        // The detail's screens are about to join the primary stack, where there's no sidebar to toggle.
        (secondaryNavigationController as? NavigationController)?.removeDetailLeadingItems()
        
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
        
        // Only a *trailing* run of secondary-preferring view controllers moves to the detail column.
        // Splitting at the first one instead would drag whatever was pushed on top of it along too
        // — e.g. search screens opened from a posts page — into the detail column, where showing a
        // new detail replaces the entire stack and throws them away.
        let viewControllers = primaryNavigationController.viewControllers
        let secondaryCount = viewControllers.reversed()
            .prefix { ($0 as? HasSplitViewPreference)?.prefersSecondaryViewController == true }
            .count
        let primaryStack = viewControllers.dropLast(secondaryCount)
        let secondaryStack = viewControllers.suffix(secondaryCount)
        primaryNavigationController.viewControllers = Array(primaryStack)
        let secondaryNavigationController = createEmptyDetailNavigationController()
        if secondaryStack.isEmpty {
            secondaryNavigationController.pushViewController(EmptyViewController(), animated: false)
        } else {
            for vc in secondaryStack {
                secondaryNavigationController.pushViewController(vc, animated: false)
            }
        }
        
        // The new column's screens pick up their sidebar toggle from this mode as they first show.
        (secondaryNavigationController as? NavigationController)?.sidebarDisplayMode = splitViewController.displayMode

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
        _ svc: UISplitViewController,
        willChangeTo displayMode: UISplitViewController.DisplayMode
    ) {
        propagateSidebarDisplayMode(displayMode)
        guard !svc.isCollapsed else { return }
        switch displayMode {
        case .secondaryOnly:
            // The sidebar's lists claim first responder as they appear (for undo) and let it go
            // as they leave, which would strand the thread's own key commands until the web view
            // is tapped. Hand first responder to the thread as the sidebar goes.
            topPostsPageViewController?.becomeFirstResponder()

            // Outside a size transition, only the user's sidebar button dismisses a
            // *pinned* sidebar: remember that choice — including across backgrounding —
            // until they summon the sidebar again.
            if svc.displayMode == .oneBesideSecondary, !isTransitioningSize {
                userHidPinnedSidebar = true
            }
        case .oneBesideSecondary, .oneOverSecondary:
            // The sidebar is coming on screen (our show methods, UIKit's edge swipe, or
            // the system sidebar button): any remembered manual hide is over.
            userHidPinnedSidebar = false
        default:
            break
        }

        // When UIKit hides the sidebar itself (tap on the dimmed detail view, or the
        // system sidebar button), preferredDisplayMode can be left stuck at a visible
        // mode. Restore it so a later show/rotation actually transitions. Async so we
        // don't mutate preferredDisplayMode reentrantly mid-transition.
        guard displayMode == .secondaryOnly else { return }
        DispatchQueue.main.async {
            guard svc.displayMode == .secondaryOnly else { return }
            if svc.preferredDisplayMode != .secondaryOnly {
                svc.preferredDisplayMode = .secondaryOnly
            }
        }
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        showDetail viewController: UIViewController,
        sender: Any?
    ) -> Bool {
        if splitViewController.isCollapsed {
            primaryNavigationController.pushViewController(viewController, animated: !isReplayingRestoration)
        } else {
            detailNavigationController!.setViewControllers([viewController], animated: false)
            
            // Laying out the split view now prevents it from getting caught up in the animation block that hides the primary view controller. Otherwise we get to see an ugly animated resizing of the new secondary view from a 0-rect up to full screen.
            splitViewController.view.layoutIfNeeded()
            
            splitViewController.hidePrimaryViewController(animated: !isReplayingRestoration)
        }
        
        return true
    }

    func splitView(
        _ splitView: AwfulSplitViewController,
        viewWillTransitionToSize size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        isTransitioningSize = true
        coordinator.animate(alongsideTransition: nil, completion: { context in
            self.isTransitioningSize = false

            // Re-derive the preferred display mode for the new orientation, so e.g. an
            // overlay summoned in portrait becomes a pinned sidebar in landscape instead
            // of leaving preferredDisplayMode stuck at .oneOverSecondary.
            self.configureSplitViewControllerDisplayMode()
            // (We used to misuse the delegate method `targetDisplayModeForAction(in:)` for this, but that sometimes resulted in an endless recursive call starting on iOS 13.)
            self.refreshSidebarToggles()
            for nav in self.sidebarNavigationControllers {
                nav.refreshSidebarChrome()
            }
        })
    }
    
}

// MARK: - Keyboard shortcuts and tab bar actions

extension RootViewControllerStack {

    /// App-wide key commands stay out of the way of anything presented over the root: a composer, a popover, the shortcuts sheet itself.
    var canHandleKeyCommands: Bool {
        rootViewController.presentedViewController == nil
    }

    /// Titles for the ⌘1…⌘n tab shortcuts, in tab order.
    var sidebarTabTitles: [String] {
        (tabBarController.viewControllers ?? []).enumerated().map { index, tab in
            let root = (tab as? UINavigationController)?.viewControllers.first ?? tab
            return root.title ?? root.tabBarItem.title ?? "Tab \(index + 1)"
        }
    }

    var hasSettingsTab: Bool {
        settingsTab != nil
    }

    private var settingsTab: UIViewController? {
        tabBarController.viewControllers?.first {
            ($0 as? UINavigationController)?.viewControllers.first is SettingsViewController
        }
    }

    var canToggleSidebar: Bool {
        !splitViewController.isCollapsed
    }

    var isSidebarVisible: Bool {
        [.oneBesideSecondary, .oneOverSecondary].contains(splitViewController.displayMode)
    }

    /// Refreshes what the user is reading: the detail column's thread or message when it has one, otherwise the top of the sidebar's stack.
    func refreshFocusedContent() {
        if !splitViewController.isCollapsed,
           let detail = detailNavigationController?.topViewController as? ContentRefreshable
        {
            detail.refreshContent()
        } else if let top = primaryNavigationController.topViewController as? ContentRefreshable {
            top.refreshContent()
        }
    }

    /// Refreshes the list showing in the selected sidebar tab, skipping a thread or message pushed above it in a collapsed stack.
    func refreshSidebar() {
        refreshList(in: primaryNavigationController)
    }

    /// Selects a tab as tapping it would, brings the sidebar on screen, and refreshes the tab's list.
    func selectSidebarTab(at index: Int) {
        guard let tabs = tabBarController.viewControllers, tabs.indices.contains(index) else { return }
        let tab = tabs[index]
        tabBarController.selectedViewController = tab
        splitViewController.showPrimaryViewController()
        if let nav = tab as? UINavigationController {
            refreshList(in: nav)
        }
    }

    func selectSettingsTab() {
        guard let settingsTab else { return }
        tabBarController.selectedViewController = settingsTab
        splitViewController.showPrimaryViewController()
    }

    /// Mirrors the sidebar toggle buttons: dismisses an overlay, unpins a pinned sidebar (the split view delegate remembers that), or summons a hidden one.
    func toggleSidebar() {
        let svc = splitViewController
        guard !svc.isCollapsed else { return }
        switch svc.displayMode {
        case .oneOverSecondary:
            svc.hidePrimaryViewController()
        case .oneBesideSecondary:
            UIView.animate(withDuration: 0.25) { svc.preferredDisplayMode = .secondaryOnly }
        default:
            svc.showPrimaryViewController()
        }
    }

    func presentKeyboardShortcuts() {
        guard rootViewController.presentedViewController == nil else { return }
        rootViewController.present(KeyboardShortcutsViewController.makeSheet(), animated: true)
    }

    /// Re-tapping the selected tab: UIKit pops the tab to its root, and the root's list goes back to the top.
    func scrollTabToTop(_ tab: UIViewController) {
        let root = (tab as? UINavigationController)?.viewControllers.first ?? tab
        DispatchQueue.main.async {
            (root as? ScrollableToTop)?.scrollToTop(animated: true)
        }
    }

    private func refreshList(in navigationController: UINavigationController) {
        for viewController in navigationController.viewControllers.reversed() {
            if viewController is HasSplitViewPreference { continue }
            if let refreshable = viewController as? ContentRefreshable {
                refreshable.refreshContent()
                return
            }
        }
    }
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
