//  PostsPageRefreshSpinnerView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshSpinnerView: UIView, PostsPageRefreshControlContent {
    private let arrows: UIImageView
    
    init() {
        arrows = UIImageView(image: UIImage(named: "pull-to-refresh")!)
        super.init(frame: CGRect.zero)
        
        arrows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrows)
        
        arrows.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        arrows.bottomAnchor.constraintEqualToAnchor(bottomAnchor).active = true
        arrows.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func transitionFromState(oldState: PostsPageRefreshControl.State, toState newState: PostsPageRefreshControl.State) {
        switch (oldState, newState) {
        case (.Waiting, .Waiting), (.Triggered, .Triggered), (.Refreshing, .Refreshing):
            break
            
        case (.Waiting, .Triggered):
            rotateArrows(CGFloat(M_PI_2))
            
        case (_, .Refreshing):
            rotateArrowsForever()
            
        case (_, .Waiting):
            rotateArrows(0)
            stopRotatingForever()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    private func rotateArrows(angle: CGFloat) {
        UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
            self.arrowsRotation = angle
            }, completion: nil)
    }
    
    private var arrowsRotation: CGFloat = 0 {
        didSet {
            if arrowsRotation == 0 {
                arrows.transform = CGAffineTransformIdentity
            } else {
                arrows.transform = CGAffineTransformMakeRotation(arrowsRotation)
            }
        }
    }
    
    private func rotateArrowsForever() {
        let existingAnimationKeys = arrows.layer.animationKeys() ?? []
        guard !existingAnimationKeys.contains(indefiniteRotationAnimationKey) else {
            return
        }
        
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = arrowsRotation
        animation.toValue = arrowsRotation + (2 * CGFloat(M_PI))
        animation.duration = 1
        animation.repeatCount = .infinity
        arrows.layer.addAnimation(animation, forKey: indefiniteRotationAnimationKey)
        
        arrowsRotation = 0
    }
    
    private func stopRotatingForever() {
        arrows.layer.removeAnimationForKey(indefiniteRotationAnimationKey)
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageRefreshControl.State = .Waiting(triggeredFraction: 0) {
        didSet {
            transitionFromState(oldValue, toState: state)
        }
    }
}

private let indefiniteRotationAnimationKey = "RotateForever"
