//  PostsPageRefreshArrowView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshArrowView: UIView, PostsPageRefreshControlContent {
    fileprivate let arrow: UIImageView
    fileprivate let spinner: UIActivityIndicatorView
    fileprivate struct Angles {
        static let triggered = CGFloat(0)
        static let waiting = CGFloat(-M_PI_2)
    }
    
    init() {
        let image = UIImage(named: "arrowright")!
        arrow = UIImageView(image: image)
        spinner = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        
        super.init(frame: CGRect(origin: CGPoint.zero, size: image.size))
        
        arrow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrow)
        
        arrow.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        arrow.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        
        spinner.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        rotateArrow(Angles.waiting, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func transitionFromState(_ oldState: PostsPageRefreshControl.State, toState newState: PostsPageRefreshControl.State) {
        switch (oldState, newState) {
        case (.waiting, .waiting), (.triggered, .triggered), (.refreshing, .refreshing):
            break
            
        case (.waiting, .triggered):
            rotateArrow(Angles.triggered, animated: true)
            
        case (_, .refreshing):
            arrow.isHidden = true
            spinner.startAnimating()
            
        case (_, .waiting):
            arrow.isHidden = false
            rotateArrow(Angles.waiting, animated: true)
            spinner.stopAnimating()
            
        default:
            fatalError("unexpected transition from \(oldState) to \(newState)")
        }
    }
    
    fileprivate func rotateArrow(_ angle: CGFloat, animated: Bool) {
        let duration = animated ? 0.3 : 0
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: { () -> Void in
            self.arrow.transform = angle == 0 ? .identity : CGAffineTransform(rotationAngle: angle)
            }, completion: nil)
    }
    
    // MARK: UIView
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        
        spinner.color = tintColor
    }
    
    override var intrinsicContentSize : CGSize {
        let arrowSize = arrow.intrinsicContentSize
        let longestArrowSize = max(arrowSize.width, arrowSize.height)
        let spinnerSize = spinner.intrinsicContentSize
        return CGSize(
            width: max(longestArrowSize, spinnerSize.width),
            height: max(longestArrowSize, spinnerSize.height))
    }
    
    // MARK: PostsPageRefreshControlContent
    
    var state: PostsPageRefreshControl.State = .waiting(triggeredFraction: 0) {
        didSet {
            transitionFromState(oldValue, toState: state)
        }
    }
}
