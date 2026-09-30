//  UnpoppingViewHandler.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import UIKit

final class UnpoppingViewHandler: UIPercentDrivenInteractiveTransition {
    let navigationController: UINavigationController
    var viewControllers: [UIViewController] = []
    private(set) var interactiveUnpopIsTakingPlace = false
    var navigationControllerIsAnimating = false

    /// Horizontal speed (points per second) past which releasing the finger commits to, or abandons, the unpop regardless of how far it got.
    private static let flickVelocity: CGFloat = 500

    private lazy var edgePanRecognizer: UIGestureRecognizer = {
        let pan = UIScreenEdgePanGestureRecognizer()
        pan.addTarget(self, action: #selector(handlePan))
        pan.delegate = self
        pan.edges = .right
        return pan
    }()

    /// On iOS 26+, where the system pop works from anywhere, a leftward swipe starting anywhere unpops too. Waits on the edge recognizer so a swipe from the right edge still goes there.
    private lazy var contentPanRecognizer: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer()
        pan.addTarget(self, action: #selector(handlePan))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.require(toFail: edgePanRecognizer)
        return pan
    }()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()

        navigationController.view.addGestureRecognizer(edgePanRecognizer)
        if #available(iOS 26.0, *) {
            navigationController.view.addGestureRecognizer(contentPanRecognizer)
        }
    }
    
    deinit {
        navigationController.view.removeGestureRecognizer(edgePanRecognizer)
        if #available(iOS 26.0, *) {
            navigationController.view.removeGestureRecognizer(contentPanRecognizer)
        }
    }

    /// Fraction of the way across the screen the finger has travelled leftward, which is how far the incoming view has slid in.
    private func percentComplete(for sender: UIPanGestureRecognizer) -> CGFloat {
        guard let view = sender.view, view.bounds.width > 0 else { return 0 }
        return -sender.translation(in: view).x / view.bounds.width
    }
    
    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            guard let vc = viewControllers.last else { break }
            interactiveUnpopIsTakingPlace = true
            navigationController.pushViewController(vc, animated: true)
            
        case .changed:
            guard interactiveUnpopIsTakingPlace else { break }
            update(percentComplete(for: sender))
            
        case .cancelled, .ended:
            guard interactiveUnpopIsTakingPlace else { break }
            // Swipes from mid-screen tend to be short, so a flick counts as much as distance does.
            let velocity = sender.velocity(in: sender.view).x
            let completes = sender.state == .ended
                && (velocity < -Self.flickVelocity || (velocity <= Self.flickVelocity && percentComplete(for: sender) > 0.3))
            if completes {
                viewControllers.removeLast()
                finish()
            } else {
                cancel()
            }
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
        // We get a call to didPopViewController when the interactive pop starts, but no (automatic) inverse call if the gesture is cancelled. This cleans up the state by removing the falsely stacked controller.
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
        guard
            let toVC = context.viewController(forKey: .to),
            let toView = context.view(forKey: .to),
            let fromView = context.view(forKey: .from)
            else { return }

        context.containerView.addSubview(fromView)
        context.containerView.addSubview(toView)
        
        let toTargetFrame = context.finalFrame(for: toVC)
        toView.frame = toTargetFrame.offsetBy(dx: toTargetFrame.width, dy: 0)
        
        let fromTargetFrame = fromView.frame.offsetBy(dx: -fromView.frame.width / 3, dy: 0)

        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: .curveLinear, animations: { 
            toView.frame = toTargetFrame
            fromView.frame = fromTargetFrame
        }, completion: { finished in
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
        // Leftward drags on an editing list belong to it: reordering, and the swipe actions that only exist while editing.
        var cur = touch.view
        while let view = cur {
            if let tableView = cur as? UITableView {
                return !tableView.isEditing
            }
            if let collectionView = cur as? UICollectionView, collectionView.isEditing {
                return false
            }
            cur = view.superview
        }

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !viewControllers.isEmpty && !navigationControllerIsAnimating else { return false }
        guard gestureRecognizer === contentPanRecognizer, let view = gestureRecognizer.view else { return true }

        // Don't hijack a text-selection drag in a posts web view, e.g. back on a thread after "Their posts" or a rap sheet.
        let location = contentPanRecognizer.location(in: view)
        if let hit = view.hitTest(location, with: nil),
           let renderView = hit.responderChain.first(where: { $0 is RenderView }) as? RenderView,
           renderView.hasTextSelection
        {
            return false
        }
        // Only for horizontal-dominant leftward motion; rightward is the system's pop.
        let translation = contentPanRecognizer.translation(in: view)
        return translation.x < 0 && abs(translation.x) > abs(translation.y)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Otherwise the web view's or list's scroll pan wins and the content pan never fires. Same as `AwfulSplitViewController.revealSidebarPan`.
        if gestureRecognizer === contentPanRecognizer {
            return true
        }
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

    /// Whatever was staged for unpop belonged to the stack that just got thrown away, so unpopping
    /// one would splice an unrelated view controller on top. Same reasoning as `didPushViewController`.
    func navigationControllerDidReplaceStack(_ navigationController: UINavigationController) {
        guard !interactiveUnpopIsTakingPlace else { return }
        viewControllers.removeAll()
    }
}
