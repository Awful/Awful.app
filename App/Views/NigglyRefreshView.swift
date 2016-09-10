//
//  NigglyRefreshView.swift
//  Awful
//
//  Created by Nolan Waite on 2016-06-22.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

import PullToRefresh
import UIKit

private let verticalMargin: CGFloat = 10

final class NigglyRefreshView: UIView, RefreshViewAnimator {
    static func makeImage() -> UIImage {
        return UIImage.animatedImageNamed("niggly-throbber", duration: 1.240)!
    }
    
    override init(frame: CGRect) {
        let image = NigglyRefreshView.makeImage()
        
        var frame = frame
        frame.size.height = max(frame.height, image.size.height + verticalMargin * 2)
        super.init(frame: frame)
        
        layer.contentsGravity = kCAGravityCenter
        layer.contentsScale = image.scale
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func addAnimation() {
        guard layer.animation(forKey: "sprite") == nil else { return }
        layer.add(makeSpriteAnimation(for: NigglyRefreshView.makeImage()), forKey: "sprite")
    }
    
    fileprivate func removeAnimation() {
        layer.removeAnimation(forKey: "sprite")
    }
    
    func animateState(_ state: State) {
        switch state {
        case .initial:
            removeAnimation()
            
        case .releasing(let progress) where progress < 1:
            addAnimation()
            layer.pause()
            
        case .loading, .releasing:
            layer.resume()
            
        case .finished:
            layer.pause()
        }
    }
}


private extension CALayer {
    func pause() {
        guard speed != 0 else { return }
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0.0
        timeOffset = pausedTime
    }
    
    func resume() {
        guard speed == 0 else { return }
        let pausedTime = timeOffset
        speed = 1.0
        timeOffset = 0.0
        beginTime = 0.0
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        beginTime = timeSincePause
    }
}


private func makeSpriteAnimation(for image: UIImage) -> CAAnimation {
    let images = image.images!
    
    let animation = CAKeyframeAnimation(keyPath: "contents")
    animation.calculationMode = kCAAnimationDiscrete
    animation.values = images.map { $0.cgImage! }
    animation.duration = image.duration
    animation.repeatCount = Float.infinity
    animation.keyTimes = (images.indices.map { Float($0) / Float(images.count) } + [1.0]).map { NSNumber(value: $0) }
    return animation
}
