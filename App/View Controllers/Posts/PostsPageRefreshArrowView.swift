//  PostsPageRefreshArrowView.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PostsPageRefreshArrowView: UIView, PostsPageRefreshControlContent {
    private let arrow: UIImageView
    private let spinner: UIActivityIndicatorView
    
    private struct Angles {
        static let triggered = CGFloat(0)
        static let waiting = CGFloat(-Double.pi / 2)
    }
    
    init() {
        let image = UIImage(named: "arrowright")!
        arrow = UIImageView(image: image)
        spinner = UIActivityIndicatorView(style: .whiteLarge)
        
        super.init(frame: CGRect(origin: .zero, size: image.size))
        
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
    
    private func transition(from oldState: PostsPageView.RefreshControlState, to newState: PostsPageView.RefreshControlState) {
        switch (oldState, newState) {
        case (_, .ready),
             (_, .awaitingScrollEnd):
            arrow.isHidden = false
            rotateArrow(Angles.waiting, animated: true)
            spinner.stopAnimating()
            
        case (.armed, .triggered):
            rotateArrow(Angles.triggered, animated: true)
            
        case (.refreshing, .refreshing):
            break
        case (_, .refreshing):
            arrow.isHidden = true
            spinner.startAnimating()

        case (_, .armed):
            arrow.isHidden = false
            rotateArrow(Angles.waiting, animated: true)
            spinner.stopAnimating()
            
        case (.ready, _),
             (.armed, _),
             (.awaitingScrollEnd, _),
             (.triggered, _),
             (.refreshing, _):
            break
        }
    }
    
    private func rotateArrow(_ angle: CGFloat, animated: Bool) {
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
    
    var state: PostsPageView.RefreshControlState = .ready {
        didSet {
            transition(from: oldValue, to: state)
        }
    }
    
    // MARk: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
