//  PostsPageRefreshArrowView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshArrowView: UIView, PostsPageRefreshControlContent {
    private let arrow: UIImageView
    private let spinner: UIActivityIndicatorView
    private struct Angles {
        static let triggered = CGFloat(0)
        static let waiting = CGFloat(M_PI_2)
    }
    
    init() {
        let image = UIImage(named: "arrowright")!
        arrow = UIImageView(image: image)
        spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        
        super.init(frame: CGRect(origin: CGPoint.zero, size: image.size))
        
        arrow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrow)
        
        arrow.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        arrow.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        
        spinner.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        spinner.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true
        
        rotateArrow(Angles.waiting, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func transitionFromState(oldState: PostsPageRefreshControl.State, toState newState: PostsPageRefreshControl.State) {
        switch (oldState, newState) {
        case (.Waiting, .Waiting), (.Triggered, .Triggered), (.Refreshing, .Refreshing):
            break
            
        case (.Waiting, .Triggered):
            rotateArrow(Angles.triggered, animated: true)
            
        case (_, .Refreshing):
            arrow.hidden = true
            spinner.startAnimating()
            
        case (_, .Waiting):
            arrow.hidden = false
            rotateArrow(Angles.waiting, animated: true)
            spinner.stopAnimating()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    private func rotateArrow(angle: CGFloat, animated: Bool) {
        let duration = animated ? 0.2 : 0
        UIView.animateWithDuration(duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: { () -> Void in
            self.arrow.transform = angle == 0 ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(angle)
            }, completion: nil)
    }
    
    // MARK: UIView
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        
        spinner.color = tintColor
    }
    
    override func intrinsicContentSize() -> CGSize {
        let arrowSize = arrow.intrinsicContentSize()
        let longestArrowSize = max(arrowSize.width, arrowSize.height)
        let spinnerSize = spinner.intrinsicContentSize()
        return CGSize(
            width: max(longestArrowSize, spinnerSize.width),
            height: max(longestArrowSize, spinnerSize.height))
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageRefreshControl.State = .Waiting(triggeredFraction: 0) {
        didSet {
            transitionFromState(oldValue, toState: state)
        }
    }
}
