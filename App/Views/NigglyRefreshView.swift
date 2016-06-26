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
        return UIImageView(image: image)
    }
    
    private let imageView = NigglyRefreshView.makeImageView()
    
    override init(frame: CGRect) {
        var frame = frame
        frame.size.height = max(frame.height, imageView.bounds.height + verticalMargin * 2)
        super.init(frame: frame)
        
        imageView.startAnimating()
        imageView.layer.pause()
        
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
                imageView.layer.pause()
                
            case .Pulling:
                imageView.layer.resume()
                
            case .Refreshing, .WillRefresh:
                imageView.layer.resume()
                
            case .NoMoreData:
                break
            }
        }
    }
}

private extension CALayer {
    func pause() {
        guard speed != 0 else { return }
        let pausedTime = convertTime(CACurrentMediaTime(), fromLayer: nil)
        speed = 0.0
        timeOffset = pausedTime
    }
    
    func resume() {
        guard speed == 0 else { return }
        let pausedTime = timeOffset
        speed = 1.0
        timeOffset = 0.0
        beginTime = 0.0
        let timeSincePause = convertTime(CACurrentMediaTime(), fromLayer: nil) - pausedTime
        beginTime = timeSincePause
    }
}
