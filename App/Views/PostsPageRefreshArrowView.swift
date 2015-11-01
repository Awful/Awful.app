//  PostsPageRefreshArrowView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshArrowView: UIView, PostsPageRefreshControlContent {
    private let arrow: UIImageView
    private let spinner: UIActivityIndicatorView
    private let triggeredAngle: CGFloat
    
    init(rotation: PostsPageRefreshArrowRotation) {
        let image = UIImage(named: "pull-to-refresh-arrow")!
        arrow = UIImageView(image: image)
        spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        triggeredAngle = rotation.angle
        
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func transitionFromState(oldState: PostsPageRefreshControl.State, toState newState: PostsPageRefreshControl.State) {
        switch (oldState, newState) {
        case (.Waiting, .Triggered):
            animateRotation(triggeredAngle)
            
        case (_, .Refreshing):
            arrow.hidden = true
            spinner.startAnimating()
            
        case (_, .Waiting):
            arrow.hidden = false
            animateRotation(0)
            spinner.stopAnimating()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    private func animateRotation(angle: CGFloat) {
        UIView.animateWithDuration(0.2, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: { () -> Void in
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
        let spinnerSize = spinner.intrinsicContentSize()
        return CGSize(
            width: max(arrowSize.width, spinnerSize.width),
            height: max(arrowSize.height, spinnerSize.height))
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageRefreshControl.State = .Waiting {
        didSet {
            if oldValue != state {
                transitionFromState(oldValue, toState: state)
            }
        }
    }
}

@objc enum PostsPageRefreshArrowRotation: Int {
    case Down, Right
    
    private var angle: CGFloat {
        switch self {
        case .Down:
            return CGFloat(M_PI)
            
        case .Right:
            return CGFloat(M_PI_2)
        }
    }
}
