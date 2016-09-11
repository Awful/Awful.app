//  PostsPageRefreshSpinnerView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshSpinnerView: UIView, PostsPageRefreshControlContent {
    fileprivate let arrows: UIImageView
    
    init() {
        arrows = UIImageView(image: UIImage(named: "pull-to-refresh")!)
        super.init(frame: CGRect.zero)
        
        arrows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrows)
        
        arrows.topAnchor.constraint(equalTo: topAnchor).isActive = true
        arrows.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        arrows.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func transitionFromState(_ oldState: PostsPageRefreshControl.State, toState newState: PostsPageRefreshControl.State) {
        switch (oldState, newState) {
        case (.waiting, .waiting), (.triggered, .triggered), (.refreshing, .refreshing):
            break
            
        case (.waiting, .triggered):
            rotateArrows(CGFloat(M_PI_2))
            
        case (_, .refreshing):
            rotateArrowsForever()
            
        case (_, .waiting):
            rotateArrows(0)
            stopRotatingForever()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    fileprivate func rotateArrows(_ angle: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
            self.arrowsRotation = angle
            }, completion: nil)
    }
    
    fileprivate var arrowsRotation: CGFloat = 0 {
        didSet {
            if arrowsRotation == 0 {
                arrows.transform = CGAffineTransform.identity
            } else {
                arrows.transform = CGAffineTransform(rotationAngle: arrowsRotation)
            }
        }
    }
    
    fileprivate func rotateArrowsForever() {
        let existingAnimationKeys = arrows.layer.animationKeys() ?? []
        guard !existingAnimationKeys.contains(indefiniteRotationAnimationKey) else {
            return
        }
        
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = arrowsRotation
        animation.toValue = arrowsRotation + (2 * CGFloat(M_PI))
        animation.duration = 1
        animation.repeatCount = .infinity
        arrows.layer.add(animation, forKey: indefiniteRotationAnimationKey)
        
        arrowsRotation = 0
    }
    
    fileprivate func stopRotatingForever() {
        arrows.layer.removeAnimation(forKey: indefiniteRotationAnimationKey)
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageRefreshControl.State = .waiting(triggeredFraction: 0) {
        didSet {
            transitionFromState(oldValue, toState: state)
        }
    }
}

private let indefiniteRotationAnimationKey = "RotateForever"
