//
//  NigglyRefreshView.swift
//  Awful
//
//  Created by Nolan Waite on 2016-06-22.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

import MJRefresh
import UIKit

private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: MJRefreshHeader {
    static func makeImageView() -> UIImageView {
        let image = UIImage.animatedImageNamed("niggly-throbber", duration: 1.240)!
        let rawImages = image.images!
        let symmetricalFrame = 14
        let animationImages = rawImages.suffixFrom(symmetricalFrame) + rawImages.prefixUpTo(symmetricalFrame)
        let imageView = UIImageView()
        imageView.animationImages = Array(animationImages)
        imageView.animationDuration = image.duration
        imageView.sizeToFit()
        return imageView
    }
    
    private let imageView = NigglyRefreshView.makeImageView()
    
    override init(frame: CGRect) {
        var frame = frame
        frame.size.height = max(frame.height, imageView.bounds.height + verticalMargin * 2)
        super.init(frame: frame)
        
        imageView.startAnimating()
        imageView.layer.speed = 0
        
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
    
    /// MJRefresh sets its pullingPercent while in the state setter, which is kinda unhelpful for keeping the animation going while we disappear after refreshing is complete.
    private var stateAccordingToMostRecentDidSet: MJRefreshState = .Idle
    
    override var state: MJRefreshState {
        didSet {
            stateAccordingToMostRecentDidSet = state
            switch state {
            case .Refreshing, .WillRefresh:
                let pausedTime = imageView.layer.timeOffset
                imageView.layer.speed = 1
                imageView.layer.timeOffset = 0
                imageView.layer.beginTime = 0
                let timeSincePause = imageView.layer.convertTime(CACurrentMediaTime(), fromLayer: nil) - pausedTime
                layer.beginTime = timeSincePause
                
            case .Idle, .Pulling, .NoMoreData:
                break
            }
        }
    }
    
    override var pullingPercent: CGFloat {
        didSet {
            switch stateAccordingToMostRecentDidSet {
            case .Idle:
                imageView.layer.speed = 0
                imageView.layer.timeOffset = 0
                
            case .Pulling where scrollView.dragging:
                imageView.layer.timeOffset = imageView.animationDuration * NSTimeInterval(pullingPercent)
                
            case .Pulling, .Refreshing, .WillRefresh, .NoMoreData:
                break
            }
        }
    }
}
