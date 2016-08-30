//  UnpoppingViewHandler.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class UnpoppingViewHandler: UIPercentDrivenInteractiveTransition {
    let navigationController: UINavigationController
    var viewControllers: [UIViewController] = []
    private var gestureStartPointX: CGFloat = 0
    private(set) var interactiveUnpopIsTakingPlace = false
    private var navigationControllerIsAnimating = false
    private let panRecognizer = UIScreenEdgePanGestureRecognizer()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        
        panRecognizer.addTarget(self, action: #selector(handlePan))
        panRecognizer.edges = .Right
        panRecognizer.delegate = self
        navigationController.view.addGestureRecognizer(panRecognizer)
    }
    
    deinit {
        navigationController.view.removeGestureRecognizer(panRecognizer)
    }
    
    @objc private func handlePan(sender: UIScreenEdgePanGestureRecognizer) {
        let location = sender.locationInView(sender.view)
        switch sender.state {
        case .Began:
            guard !viewControllers.isEmpty else { break }
            interactiveUnpopIsTakingPlace = true
            gestureStartPointX = location.x
            if let vc = viewControllers.last {
                navigationController.pushViewController(vc, animated: true)
            }
            
        case .Changed:
            guard interactiveUnpopIsTakingPlace else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            updateInteractiveTransition(percent)
            
        case .Cancelled, .Ended:
            guard interactiveUnpopIsTakingPlace else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            // TODO: Use [recognizer velocityInView] too?
            if percent <= 0.3 {
                cancelInteractiveTransition()
            } else {
                viewControllers.removeLast()
                finishInteractiveTransition()
            }
            gestureStartPointX = 0
            interactiveUnpopIsTakingPlace = false
            
        case .Failed, .Possible:
            break
        }
    }
    
    func navigationControllerDidBeginAnimating() {
        navigationControllerIsAnimating = true
    }
    
    func navigationControllerDidFinishAnimating() {
        navigationControllerIsAnimating = false
    }
    
    func navigationControllerDidCancelInteractivePop() {
        /// We get a call to didPopViewController when the interactive pop starts, but no (automatic) inverse call if the gesture is cancelled. This cleans up the state by removing the falsely stacked controller.
        navigationControllerIsAnimating = false
        viewControllers.removeLast()
    }
    
    func navigationControllerDidCancelInteractiveUnpop() {
        navigationControllerIsAnimating = false
    }
    
    func shouldHandleAnimatingTransitionForOperation(operation: UINavigationControllerOperation) -> Bool {
        return operation == .Push && interactiveUnpopIsTakingPlace
    }
}

extension UnpoppingViewHandler: UIViewControllerAnimatedTransitioning {
    func transitionDuration(context: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        // TODO: Can we match this up to the default? Does it matter if it will always be interactive?
        // Only takes effect when the system completes a half-swipe
        return 0.35
    }
    
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let
            toVC = context.viewController(forKey: UITransitionContextToViewControllerKey),
            let fromVC = context.viewController(forKey: UITransitionContextFromViewControllerKey)
            else { return }
        
        context.containerView?.addSubview(toVC.view)
        
        let toTargetFrame = fromVC.view.frame
        toVC.view.frame = toTargetFrame.offsetBy(dx: toTargetFrame.width, dy: 0)
        
        let fromTargetFrame = fromVC.view.frame.offsetBy(dx: -fromVC.view.frame.width / 3, dy: 0)
        
        let animateTabBar = toVC.hidesBottomBarWhenPushed && !fromVC.hidesBottomBarWhenPushed
        
        let tabBar = fromVC.tabBarController?.tabBar
        let previousParent = tabBar?.superview
        if animateTabBar, let tabBar = tabBar {
            // UIKit reparents the tab bar before this method gets called; restore its logical position.
            let wrapper = toVC.view.superview
            wrapper?.insertSubview(tabBar, belowSubview: toVC.view)
        }
        let tabBarTargetFrame: CGRect
        if let tabBar = tabBar {
            tabBarTargetFrame = tabBar.frame.offsetBy(dx: tabBar.frame.width / 3 * 2, dy: 0)
        } else {
            tabBarTargetFrame = .zero
        }
        
        UIView.animateWithDuration(transitionDuration(context), delay: 0, options: .CurveLinear, animations: { 
            toVC.view.frame = toTargetFrame
            fromVC.view.frame = fromTargetFrame
            if animateTabBar {
                tabBar?.frame = tabBarTargetFrame
            }
            
            }, completion: { finished in
                if animateTabBar, let tabBar = tabBar {
                    previousParent?.addSubview(tabBar)
                }
                
                context.completeTransition(!context.transitionWasCancelled())
        })
    }
    
    func animationEnded(transitionCompleted: Bool) {
        if !transitionCompleted {
            navigationControllerIsAnimating = false
        }
    }
}

extension UnpoppingViewHandler: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !viewControllers.isEmpty && !navigationControllerIsAnimating
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer other: UIGestureRecognizer) -> Bool {
        /**
            Allow simultaneous recognition with:
              1. The swipe-to-pop gesture recognizer.
              2. The swipe-to-show-basement gesture recognizer.
         */
        return other is UIScreenEdgePanGestureRecognizer
    }
}

protocol NavigationControllerObserver {
    func navigationController(navigationController: UINavigationController, didPopViewController viewController: UIViewController?)
    func navigationController(navigationController: UINavigationController, didPushViewController viewController: UIViewController)
}

extension UnpoppingViewHandler: NavigationControllerObserver {
    func navigationController(navigationController: UINavigationController, didPopViewController viewController: UIViewController?) {
        if let viewController = viewController {
            viewControllers.append(viewController)
        }
    }
    
    func navigationController(navigationController: UINavigationController, didPushViewController viewController: UIViewController) {
        guard !interactiveUnpopIsTakingPlace else { return }
        viewControllers.removeAll()
    }
}
