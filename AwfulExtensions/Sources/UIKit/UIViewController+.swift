//  UIViewController+.swift
//
//  Copyright 2023 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// MARK: async

public extension UIViewController {
    /// Dismisses the view controller that was presented modally by the view controller.
    func dismiss(
        animated: Bool
    ) async {
        await withCheckedContinuation { continuation in
            dismiss(animated: animated) {
                continuation.resume()
            }
        }
    }
}

// MARK: Hierarchy

public extension UIViewController {
    /**
     Returns the view controller's children, plus its presented view controller (if any), plus any hidden view controllers (if this is a known view controller that has sometimes-hidden children, e.g. `UITabBarController` tabs that are not the current tab).
     */
    var immediateDescendants: [UIViewController] {
        var immediateDescendants: [UIViewController] = []
        var alreadyAdded: Set<UIViewController> = []

        func add(_ vc: UIViewController) {
            if alreadyAdded.contains(vc) { return }
            immediateDescendants.append(vc)
            alreadyAdded.insert(vc)
        }

        if let presented = presentedViewController {
            add(presented)
        }

        children.forEach(add)

        switch self {
        case let nav as UINavigationController:
            nav.viewControllers.forEach(add)
        case let split as UISplitViewController:
            split.viewControllers.forEach(add)
        case let tab as UITabBarController:
            tab.viewControllers?.forEach(add)
        default:
            break
        }

        return immediateDescendants
    }

    /// Returns each descendant of the view controller, starting at the view controller and performing a depth-first search via `immediateDescendants`.
    var subtree: some Sequence<UIViewController> {
        AnySequence { () -> AnyIterator<UIViewController> in
            var viewControllers: [UIViewController] = [self]
            return AnyIterator {
                if viewControllers.isEmpty { return nil }
                let vc = viewControllers.removeFirst()
                viewControllers.insert(contentsOf: vc.immediateDescendants, at: 0)
                return vc
            }
        }
    }

    /// Returns the first descendant that matches the type, in the order returned by `subtree`.
    func firstDescendant<VC: UIViewController>(ofType _: VC.Type) -> VC? {
        subtree.first { $0 is VC } as! VC?
    }
}
