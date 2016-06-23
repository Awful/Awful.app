//
//  NigglyRefreshView.swift
//  Awful
//
//  Created by Nolan Waite on 2016-06-22.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

import Refresher
import UIKit

private let duration: NSTimeInterval = 1.240
private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: UIView {
    static let image = UIImage.animatedImageNamed("niggly-throbber", duration: duration)
    static let duration: NSTimeInterval = 1.240
    
    private let imageView: UIImageView = {
        let imageView = UIImageView(image: NigglyRefreshView.image)
        imageView.layer.speed = 0
        imageView.startAnimating()
        return imageView
    }()
    
    override init(frame: CGRect) {
        var frame = frame
        frame.size.height = max(frame.height, imageView.bounds.height + verticalMargin * 2)
        super.init(frame: frame)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activateConstraints([
            imageView.centerXAnchor.constraintEqualToAnchor(centerXAnchor),
            imageView.centerYAnchor.constraintEqualToAnchor(centerYAnchor),
            ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NigglyRefreshView: PullToRefreshViewDelegate {
    func pullToRefresh(view: PullToRefreshView, progressDidChange progress: CGFloat) {
        // Progress is based on our height, but there's a bit of margin before we can see :niggly:, so let's delay a little bit before we start advancing the animation.
        var progress = max(progress - 0.2, 0) / 0.8
        // And then it's a bit too quick for my liking.
        progress /= 2
        imageView.layer.timeOffset = NigglyRefreshView.duration * NSTimeInterval(progress)
    }
    
    func pullToRefresh(view: PullToRefreshView, stateDidChange state: PullToRefreshViewState) {
        // nop
    }
    
    func pullToRefreshAnimationDidStart(view: PullToRefreshView) {
        imageView.layer.beginTime = imageView.layer.timeOffset
        imageView.layer.speed = 1
    }
    
    func pullToRefreshAnimationDidEnd(view: PullToRefreshView) {
        imageView.layer.speed = 0
    }
}
