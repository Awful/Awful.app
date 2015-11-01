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
        case (.Triggered, .Triggered), (.Refreshing, .Refreshing):
            break
            
        case (.Waiting, .Waiting(let fraction)) where fraction == 0:
            quicklyAnimateToRotation(0)
            
        case (.Waiting, .Waiting(let fraction)):
            arrowsRotation = CGFloat(2 * M_PI) * fraction
            
        case (.Waiting, .Triggered):
            rotateArrowsForever()
            
        case (_, .Refreshing):
            rotateArrowsForever()
            
        case (_, .Waiting(let fraction)):
            quicklyAnimateToRotation(CGFloat(2 * M_PI) * fraction)
            stopRotatingForever()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    private func quicklyAnimateToRotation(to: CGFloat) {
        let currentRotation = arrows.layer.presentationLayer()?.valueForKeyPath("transform.rotation.z") as! CGFloat?
        
        arrowsRotation = to
        
        if var from = currentRotation {
            
            // Try to force counter-clockwise rotation. M_PI is sufficient because it's a 180º-symmetrical image.
            if from < 0 {
                from += CGFloat(M_PI)
            }
            
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = from
            animation.duration = 0.15
            animation.removedOnCompletion = true
            arrows.layer.addAnimation(animation, forKey: "cancelling indefinite rotation")
        }
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
