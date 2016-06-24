//
//  NigglyRefreshView.swift
//  Awful
//
//  Created by Nolan Waite on 2016-06-22.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

import MJRefresh
import UIKit

private let duration: NSTimeInterval = 1.240
private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: MJRefreshHeader {
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
    
    override var state: MJRefreshState {
        didSet {
            switch state {
            case .Idle:
                imageView.layer.speed = 0
                imageView.layer.timeOffset = 0
                
            case .Pulling:
                imageView.layer.speed = 0
                
            case .Refreshing, .WillRefresh:
                let pausedTime = imageView.layer.timeOffset
                imageView.layer.speed = 1
                imageView.layer.timeOffset = 0
                imageView.layer.beginTime = 0
                let timeSincePause = imageView.layer.convertTime(CACurrentMediaTime(), fromLayer: nil) - pausedTime
                layer.beginTime = timeSincePause
                
            case .NoMoreData:
                break
            }
        }
    }
    
    override var pullingPercent: CGFloat {
        didSet {
            switch state {
            case .Pulling where scrollView.dragging:
                imageView.layer.timeOffset = NigglyRefreshView.duration * NSTimeInterval(pullingPercent)
            case .Idle, .Pulling, .Refreshing, .WillRefresh, .NoMoreData:
                break
            }
        }
    }
}
