//  RootViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

/**
 The root view controller has no visual presence itself, but contains a single child view controller. Its child changes depending on whether a user is currently logged in.
 */
class RootViewController: UIViewController {

    private var child: UIViewController?
    weak var delegate: RootViewControllerDelegate?
    private(set) var isLoggedIn: Bool
    private let managedObjectContext: NSManagedObjectContext

    init(isLoggedIn: Bool, managedObjectContext: NSManagedObjectContext) {
        self.isLoggedIn = isLoggedIn
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: Child view controller

    func setIsLoggedIn(_ isLoggedIn: Bool, animated: Bool) {
        if isLoggedIn == self.isLoggedIn { return }

        self.isLoggedIn = isLoggedIn

        if isViewLoaded {
            updateChild(animated: animated)
        }
    }

    private func updateChild(animated: Bool) {
        setSingleChildViewController(to: {
            if isLoggedIn {
                let paneVC = OneOrTwoPaneViewController(managedObjectContext: managedObjectContext)
                paneVC.restorationIdentifier = "OneOrTwoPane"
                return paneVC
            } else {
                let loginVC = LoginViewController.newFromStoryboard()
                loginVC.delegate = self
                return loginVC.enclosingNavigationController
            }
        }(), animated: animated)
    }

    private func setSingleChildViewController(to newChild: UIViewController, animated: Bool) {
        let oldChild = child

        oldChild?.willMove(toParent: nil)
        addChild(newChild)

        if let oldChild = oldChild {
            view.insertSubview(newChild.view, belowSubview: oldChild.view)
        } else {
            view.addSubview(newChild.view)
        }
        newChild.view.constrain(to: view, edges: .all).activate()

        UIView.animate(withDuration: animated ? 0.3 : 0, animations: {
            oldChild?.view.alpha = 0
        }, completion: { finished in
            oldChild?.view.removeFromSuperview()
            oldChild?.removeFromParent()
            newChild.didMove(toParent: self)
        })
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        updateChild(animated: false)
    }

    override func traitCollectionDidChange(_ previousTraits: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraits)

        if
            #available(iOS 12.0, *),
            previousTraits?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            delegate?.userInterfaceStyleDidChange(in: self)
        }
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

    // MARK: Status bar

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: Delegates

protocol RootViewControllerDelegate: AnyObject {
    func userInterfaceStyleDidChange(in viewController: RootViewController)
}

extension RootViewController: LoginViewControllerDelegate {
    func didLogIn(via viewController: LoginViewController) {
        setIsLoggedIn(true, animated: true)
    }
}
