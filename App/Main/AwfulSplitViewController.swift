//  AwfulSplitViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import UIKit

/// Forwards status bar style questions to its first view controller; tells delegate when split view controller will transition to a new size.
class AwfulSplitViewController: UISplitViewController {

    override var childForStatusBarStyle : UIViewController? {
        return viewControllers.first as UIViewController?
    }

    #if !targetEnvironment(macCatalyst)
    /// Swiping rightward anywhere (not just the left screen edge, which is all modern UIKit's built-in gesture recognizes) summons the sidebar, matching the app's longtime behavior on older iOS versions.
    ///
    /// Only while `allowsSwipeToRevealSidebar`: with "Hide sidebar in landscape" off the sidebar toggle buttons are meant to be the way in and out, unless the user opts back into the swipe with "Swipe to reveal sidebar". (Before iOS 26, `presentsWithGesture` is still on, so UIKit's own left-edge swipe remains regardless; turning it off there would also hide UIKit's display mode button.)
    private lazy var revealSidebarPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPanToRevealSidebar))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        return pan
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(revealSidebarPan)
    }

    @objc private func didPanToRevealSidebar(_ pan: UIPanGestureRecognizer) {
        guard case .began = pan.state else { return }
        showPrimaryViewController()
    }

    /// Whether the rightward pan may summon the sidebar: always when the sidebar hides in landscape (there's no pinned sidebar to toggle), otherwise only when the user has asked for the swipe. Read at gesture time so a settings change applies immediately.
    private var allowsSwipeToRevealSidebar: Bool {
        let defaults = UserDefaults.standard
        return defaults.defaultingValue(for: Settings.hideSidebarInLandscape)
            || defaults.defaultingValue(for: Settings.swipeToRevealSidebar)
    }
    #endif

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        let delegate = self.delegate as? AwfulSplitViewControllerDelegate
        delegate?.splitView(self, viewWillTransitionToSize: size, with: coordinator)
    }
}

#if !targetEnvironment(macCatalyst)
extension AwfulSplitViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === revealSidebarPan else { return true }
        guard allowsSwipeToRevealSidebar else { return false }
        // Only when there's a hidden sidebar to reveal.
        guard !isCollapsed, displayMode == .secondaryOnly else { return false }
        // Don't hijack a text-selection drag in a posts/message web view.
        let location = revealSidebarPan.location(in: view)
        if let hit = view.hitTest(location, with: nil),
           let renderView = hit.responderChain.first(where: { $0 is RenderView }) as? RenderView,
           renderView.hasTextSelection
        {
            return false
        }
        // Only for horizontal-dominant rightward motion.
        let translation = revealSidebarPan.translation(in: view)
        return translation.x > 0 && abs(translation.x) > abs(translation.y)
    }

    // Let the posts web view's (and any table view's) scroll pan begin too. The web view has no horizontal scrolling, so a horizontal-dominant pan is a scrolling no-op there; without this, the scroll view's pan wins and ours never fires.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === revealSidebarPan
    }

    // Defer to screen-edge gestures: the detail nav's interactive pop (left edge, also a rightward drag) and the swipe-from-right-edge unpop. If they can't begin (e.g. nothing to pop), they fail and our pan proceeds.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === revealSidebarPan && otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
}
#endif

protocol AwfulSplitViewControllerDelegate: UISplitViewControllerDelegate {
    func splitView(
        _ splitView: AwfulSplitViewController,
        viewWillTransitionToSize size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    )
}
