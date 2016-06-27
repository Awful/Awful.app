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
    static func makeImage() -> UIImage {
        return UIImage.animatedImageNamed("niggly-throbber", duration: 1.240)!
    }
    
    override init(frame: CGRect) {
        var frame = frame
        frame.size.height = max(frame.height, NigglyRefreshView.makeImage().size.height + verticalMargin * 2)
        super.init(frame: frame)
        
        layer.contentsGravity = kCAGravityCenter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addAnimation() {
        guard layer.animationForKey("sprite") == nil else { return }
        layer.addAnimation(makeSpriteAnimation(for: NigglyRefreshView.makeImage()), forKey: "sprite")
    }
    
    private var resetAnimationNextPercentAdjustmentWhenIdle = false
    private var realState: MJRefreshState = .Idle
    
    override var state: MJRefreshState {
        didSet {
            // percentProgress changes in the state setter, so we keep the last completed state change handy.
            realState = state
            
            switch state {
            case .Idle where oldValue == .Refreshing:
                resetAnimationNextPercentAdjustmentWhenIdle = true
                
            case .Idle:
                layer.pause()
                
            case .Pulling:
                layer.resume()
                
            case .Refreshing, .WillRefresh:
                layer.resume()
                
            case .NoMoreData:
                break
            }
        }
    }
    
    override var pullingPercent: CGFloat {
        didSet {
            if pullingPercent > 0 {
                addAnimation()
            } else if realState == .Idle && pullingPercent <= 0 {
                layer.removeAnimationForKey("sprite")
                layer.pause()
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


private func makeSpriteAnimation(for image: UIImage) -> CAAnimation {
    let images = image.images!
    
    let animation = CAKeyframeAnimation(keyPath: "contents")
    animation.calculationMode = kCAAnimationDiscrete
    animation.values = images.map { $0.CGImage! }
    animation.duration = image.duration
    animation.repeatCount = Float.infinity
    animation.keyTimes = images.indices.map { Float($0) / Float(images.count) } + [1.0]
    return animation
}
