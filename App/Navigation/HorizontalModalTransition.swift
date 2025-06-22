//  HorizontalModalTransition.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A custom transition that slides modally presented view controllers horizontally from right to left,
/// mimicking a navigation controller push animation for better consistency with the app's navigation flow.
final class HorizontalModalTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35 // Match navigation controller timing
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)
        
        if isPresenting {
            // Presenting: slide new view in from right
            containerView.addSubview(toView)
            toView.frame = containerView.bounds.offsetBy(dx: containerView.bounds.width, dy: 0)
            
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                toView.frame = containerView.bounds
                fromView.frame = containerView.bounds.offsetBy(dx: -containerView.bounds.width * 0.3, dy: 0)
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        } else {
            // Dismissing: slide current view out to right
            containerView.insertSubview(toView, belowSubview: fromView)
            toView.frame = containerView.bounds.offsetBy(dx: -containerView.bounds.width * 0.3, dy: 0)
            
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                fromView.frame = containerView.bounds.offsetBy(dx: containerView.bounds.width, dy: 0)
                toView.frame = containerView.bounds
            } completion: { finished in
                transitionContext.completeTransition(finished)
            }
        }
    }
}

/// A transitioning delegate that provides the horizontal modal transition
final class HorizontalModalTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return HorizontalModalTransition(isPresenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return HorizontalModalTransition(isPresenting: false)
    }
} 