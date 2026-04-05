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
        alpha = 0.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func transition(from oldState: PostsPageView.RefreshControlState, to newState: PostsPageView.RefreshControlState) {
        switch (oldState, newState) {
        case (.armed, .triggered):
            rotateArrows(CGFloat(Double.pi / 2))

        case (.refreshing, .refreshing):
            break
        case (_, .refreshing):
            rotateArrowsForever()
            
        case (.armed, .armed):
            break
        case (_, .armed):
            rotateArrows(0)
            stopRotatingForever()
            
        case (.disabled, _),
             (.ready, _),
             (.armed, _),
             (.awaitingScrollEnd, _),
             (.triggered, _),
             (.refreshing, _):
            break
        }
    }
    
    private func rotateArrows(_ angle: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
            self.arrowsRotation = angle
            }, completion: nil)
    }
    
    private var arrowsRotation: CGFloat = 0 {
        didSet {
            if arrowsRotation == 0 {
                arrows.transform = CGAffineTransform.identity
            } else {
                arrows.transform = CGAffineTransform(rotationAngle: arrowsRotation)
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
        animation.toValue = arrowsRotation + (2 * CGFloat(Double.pi))
        animation.duration = 1
        animation.repeatCount = .infinity
        arrows.layer.add(animation, forKey: indefiniteRotationAnimationKey)
        
        arrowsRotation = 0
    }
    
    fileprivate func stopRotatingForever() {
        arrows.layer.removeAnimation(forKey: indefiniteRotationAnimationKey)
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageView.RefreshControlState = .ready {
        didSet {
            transition(from: oldValue, to: state)

            switch state {
            case .ready, .disabled:
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 0.0
                }

            case .armed(let triggeredFraction):
                let targetAlpha = min(1.0, triggeredFraction * 2)
                UIView.animate(withDuration: 0.1) {
                    self.alpha = targetAlpha
                }

            case .triggered, .refreshing:
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 1.0
                }

            case .awaitingScrollEnd:
                break
            }
        }
    }
}

private let indefiniteRotationAnimationKey = "RotateForever"
