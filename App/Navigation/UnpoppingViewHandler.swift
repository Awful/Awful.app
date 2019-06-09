//  UnpoppingViewHandler.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class UnpoppingViewHandler: UIPercentDrivenInteractiveTransition {
    let navigationController: UINavigationController
    var viewControllers: [UIViewController] = []
    private var gestureStartPointX: CGFloat = 0
    private(set) var interactiveUnpopIsTakingPlace = false
    var navigationControllerIsAnimating = false

    private lazy var panRecognizer: UIGestureRecognizer = {
        let pan = UIScreenEdgePanGestureRecognizer()
        pan.addTarget(self, action: #selector(handlePan))
        pan.delegate = self
        pan.edges = .right
        return pan
    }()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()

        navigationController.view.addGestureRecognizer(panRecognizer)
    }
    
    deinit {
        navigationController.view.removeGestureRecognizer(panRecognizer)
    }
    
    @objc private func handlePan(_ sender: UIScreenEdgePanGestureRecognizer) {
        let location = sender.location(in: sender.view)
        switch sender.state {
        case .began:
            guard !viewControllers.isEmpty else { break }
            interactiveUnpopIsTakingPlace = true
            gestureStartPointX = location.x
            if let vc = viewControllers.last {
                navigationController.pushViewController(vc, animated: true)
            }
            
        case .changed:
            guard interactiveUnpopIsTakingPlace else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            update(percent)
            
        case .cancelled, .ended:
            guard interactiveUnpopIsTakingPlace else { break }
            let percent = (gestureStartPointX - location.x) / gestureStartPointX
            // TODO: Use [recognizer velocityInView] too?
            if percent <= 0.3 {
                cancel()
            } else {
                viewControllers.removeLast()
                finish()
            }
            gestureStartPointX = 0
            interactiveUnpopIsTakingPlace = false
            
        case .failed, .possible:
            break

        @unknown default:
            assertionFailure("handle unknown gesture recognizer state")
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
    
    func shouldHandleAnimatingTransitionForOperation(_ operation: UINavigationController.Operation) -> Bool {
        return operation == .push && interactiveUnpopIsTakingPlace
    }
}

extension UnpoppingViewHandler: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        // TODO: Can we match this up to the default? Does it matter if it will always be interactive?
        // Only takes effect when the system completes a half-swipe
        return 0.35
    }
    
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let
            toVC = context.viewController(forKey: UITransitionContextViewControllerKey.to),
            let fromVC = context.viewController(forKey: UITransitionContextViewControllerKey.from)
            else { return }
        
        context.containerView.addSubview(toVC.view)
        
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
        
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: .curveLinear, animations: { 
            toVC.view.frame = toTargetFrame
            fromVC.view.frame = fromTargetFrame
            if animateTabBar {
                tabBar?.frame = tabBarTargetFrame
            }
            
            }, completion: { finished in
                if animateTabBar, let tabBar = tabBar {
                    previousParent?.addSubview(tabBar)
                }
                
                context.completeTransition(!context.transitionWasCancelled)
        })
    }
    
    func animationEnded(_ transitionCompleted: Bool) {
        if !transitionCompleted {
            navigationControllerIsAnimating = false
        }
    }
}

extension UnpoppingViewHandler: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Since we're on the right edge, the recognizer interferes with reordering UITableView.
        var cur = touch.view
        while let view = cur {
            if let tableView = cur as? UITableView {
                return !tableView.isEditing
            }
            cur = view.superview
        }

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !viewControllers.isEmpty && !navigationControllerIsAnimating
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition with the swipe-to-pop gesture recognizer.
        return other is UIScreenEdgePanGestureRecognizer
    }
}

extension UnpoppingViewHandler {
    func navigationController(_ navigationController: UINavigationController, didPopViewController viewController: UIViewController?) {
        if let viewController = viewController {
            viewControllers.append(viewController)
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, didPushViewController viewController: UIViewController) {
        guard !interactiveUnpopIsTakingPlace else { return }
        viewControllers.removeAll()
    }
}
