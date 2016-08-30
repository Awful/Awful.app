//  NavigationController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Adds theming support; hosts instances of NavigationBar and Toolbar; shows and hides the toolbar depending on whether the view controller has toolbar items; and, on iPhone, allows swiping from the *right* screen edge to unpop a view controller.
final class NavigationController: UINavigationController {
    private weak var realDelegate: UINavigationControllerDelegate?
    private lazy var unpopHandler: UnpoppingViewHandler? = {
        guard UIDevice.currentDevice().userInterfaceIdiom == .Phone else { return nil }
        return UnpoppingViewHandler(navigationController: self)
    }()
    private var pushAnimationInProgress = false
    
    // We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our navigation bar and toolbar classes are used.
    
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }
    
    init() {
        super.init(navigationBarClass: NavigationBar.self, toolbarClass: Toolbar.self)
        restorationClass = type(of: self)
        delegate = self
    }
    
    override convenience init(rootViewController: UIViewController) {
        self.init()
        viewControllers = [rootViewController]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Swipe to unpop
    
    override func popViewControllerAnimated(animated: Bool) -> UIViewController? {
        let viewController = super.popViewControllerAnimated(animated)
        unpopHandler?.navigationController(self, didPopViewController: viewController)
        return viewController
    }
    
    override func popToViewController(viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        let popped = super.popToViewController(viewController, animated: animated)
        for viewController in popped ?? [] {
            unpopHandler?.navigationController(self, didPopViewController: viewController)
        }
        return popped
    }
    
    override func popToRootViewControllerAnimated(animated: Bool) -> [UIViewController]? {
        let popped = super.popToRootViewControllerAnimated(animated)
        for viewController in popped ?? [] {
            unpopHandler?.navigationController(self, didPopViewController: viewController)
        }
        return popped
    }
    
    override func pushViewController(viewController: UIViewController, animated: Bool) {
        pushAnimationInProgress = true
        
        super.pushViewController(viewController, animated: animated)
        
        unpopHandler?.navigationController(self, didPushViewController: viewController)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        themeDidChange()
        
        interactivePopGestureRecognizer?.delegate = self
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        let theme = Theme.currentTheme
        
        navigationBar.tintColor = theme["navigationBarTextColor"]
        navigationBar.barTintColor = theme["navigationBarTintColor"]
        
        toolbar?.tintColor = theme["toolbarTextColor"]
        toolbar?.barTintColor = theme["toolbarTintColor"]
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(unpopHandler?.viewControllers, forKey: Key.FutureViewControllers.rawValue)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        if let viewControllers = coder.decodeObjectForKey(Key.FutureViewControllers.rawValue) as? [UIViewController] {
            unpopHandler?.viewControllers = viewControllers
        }
    }
    
    // MARK: Delegate delegation
    
    override weak var delegate: UINavigationControllerDelegate? {
        didSet {
            if delegate === self {
                realDelegate = nil
            } else {
                realDelegate = delegate
                delegate = self
            }
        }
    }
    
    override func respondsToSelector(selector: Selector) -> Bool {
        return super.respondsToSelector(selector) || realDelegate?.respondsToSelector(selector) ?? false
    }
    
    override func forwardingTargetForSelector(selector: Selector) -> AnyObject? {
        if let realDelegate = realDelegate , realDelegate.respondsToSelector(selector) {
            return realDelegate
        }
        return nil
    }
}

private enum Key: String {
    case FutureViewControllers = "AwfulFutureViewControllers"
}

extension NavigationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Disable swipe-to-pop gesture recognizer during pop animations and when we have nothing to pop. If we don't do this, something bad happens in conjunction with the swipe-to-unpop that causes a pushed view controller not to actually appear on the screen. It looks like the app has simply frozen.
        // See http://holko.pl/ios/2014/04/06/interactive-pop-gesture/ for more, and https://github.com/fastred/AHKNavigationController for the fix.
        return viewControllers.count > 1 && !pushAnimationInProgress
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        /*
            Allow simultaneous recognition with:
         
                1. The swipe-to-unpop gesture recognizer.
                2. The swipe-to-show-basement gesture recognizer.
         */
        return otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
}

extension NavigationController: UINavigationControllerDelegate {
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        setToolbarHidden(viewController.toolbarItems?.count ?? 0 == 0, animated: animated)
        
        if let unpopHandler = unpopHandler , animated {
            unpopHandler.navigationControllerDidBeginAnimating()
            
            // We need to hook into the transitionCoordinator's notifications as well as -...didShowViewController: because the latter isn't called when the default interactive pop action is cancelled.
            // See http://stackoverflow.com/questions/23484310
            navigationController.transitionCoordinator()?.notifyWhenInteractionEndsUsingBlock({ (context) in
                guard context.isCancelled() else { return }
                let unpopping = unpopHandler.interactiveUnpopIsTakingPlace
                let completion = context.transitionDuration() * Double(context.percentComplete())
                var viewControllerCount = navigationController.viewControllers.count
                if !unpopping {
                    viewControllerCount += 1
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(completion * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                    if unpopping {
                        unpopHandler.navigationControllerDidCancelInteractiveUnpop()
                    } else {
                        unpopHandler.navigationControllerDidCancelInteractivePop()
                    }
                    
                    self.pushAnimationInProgress = false
                })
            })
        }
        
        realDelegate?.navigationController?(navigationController, willShowViewController: viewController, animated: animated)
    }
    
    func navigationController(navigationController: UINavigationController, didShowViewController viewController: UIViewController, animated: Bool) {
        if animated {
            unpopHandler?.navigationControllerDidFinishAnimating()
        }
        
        pushAnimationInProgress = false
        
        realDelegate?.navigationController?(navigationController, didShowViewController: viewController, animated: animated)
    }
    
    func navigationController(navigationController: UINavigationController, interactionControllerForAnimationController animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if let unpopHandler = unpopHandler {
            return unpopHandler
        }
        
        return realDelegate?.navigationController?(navigationController, interactionControllerForAnimationController: animationController)
    }
    
    func navigationController(navigationController: UINavigationController, animationControllerForOperation operation: UINavigationControllerOperation, fromViewController fromVC: UIViewController, toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let unpopHandler = unpopHandler , unpopHandler.shouldHandleAnimatingTransitionForOperation(operation) {
            return unpopHandler
        }
        
        return realDelegate?.navigationController?(navigationController, animationControllerForOperation: operation, fromViewController: fromVC, toViewController: toVC)
    }
}

extension NavigationController: UIViewControllerRestoration {
    static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        let nav = self.init()
        nav.restorationIdentifier = identifierComponents.last as? String
        return nav
    }
}
