//  SpriteSheetView.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
    An animation view that loads a sprite sheet.
 
    The sprite sheet is a single image with multiple frames stacked in a single column with no spacing in between.
 
    Animation is done by updating a `CALayer`'s `contentRect`.
 */
public final class SpriteSheetView: UIView {
    private let spriteLayer = CALayer()
    
    /// An image of multiple frames stacked in a single column. Each frame is assumed to be a square.
    public var spriteSheet: UIImage? {
        didSet { updateForSpriteSheet() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }
    
    /// Initializes the view with an appropriate size for the sprite sheet.
    public convenience init(spriteSheet: UIImage) {
        let size = CGSize(width: spriteSheet.size.width, height: spriteSheet.size.width)
        self.init(frame: CGRect(origin: .zero, size: size))
        
        self.spriteSheet = spriteSheet
        updateForSpriteSheet()
    }
    
    /// How quickly to play the animation, in number of frames per second.
    public var frameRate: Int = 60
    
    private var sheetInfo: SheetInfo?
    
    private struct SheetInfo {
        let sheetSize: CGSize
        
        var singleFrameWidth: CGFloat {
            return sheetSize.width
        }
        
        var numberOfFrames: Int {
            return Int(sheetSize.height / singleFrameWidth)
        }
        
        var singleFrameWidthInPercent: CGFloat {
            return 1 / CGFloat(numberOfFrames)
        }
        
        init(_ image: UIImage) {
            sheetSize = image.size
        }
    }
    
    private func updateForSpriteSheet() {
        stopAnimating()
        
        sheetInfo = spriteSheet.map(SheetInfo.init)
        
        if spriteLayer.superlayer == nil {
            layer.addSublayer(spriteLayer)
            setNeedsLayout()
        }
        
        invalidateIntrinsicContentSize()
        
        CATransaction.begin()
        defer { CATransaction.commit() }
        CATransaction.setDisableActions(true)
        
        spriteLayer.contents = spriteSheet?.cgImage
        
        guard let sheetInfo = self.sheetInfo else { return }
        
        spriteLayer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: sheetInfo.singleFrameWidthInPercent)
    }
    
    /// Starts the animation in an infinite loop.
    public func startAnimating() {
        stopAnimating()
        
        guard let sheetInfo = self.sheetInfo else { return }
        
        let frameRange = 0 ..< sheetInfo.numberOfFrames
        let contentsRects = frameRange.map { CGRect(
            x: 0,
            y: CGFloat($0) * sheetInfo.singleFrameWidthInPercent,
            width: 1,
            height: sheetInfo.singleFrameWidthInPercent)
        }
        let keyTimes = frameRange.map { CGFloat($0) * sheetInfo.singleFrameWidthInPercent }
        
        let animation = CAKeyframeAnimation()
        animation.duration = TimeInterval(sheetInfo.numberOfFrames) / TimeInterval(frameRate)
        animation.values = contentsRects
        animation.keyTimes = keyTimes as [NSNumber]
        animation.keyPath = #keyPath(CALayer.contentsRect)
        animation.calculationMode = kCAAnimationDiscrete
        animation.repeatCount = Float.greatestFiniteMagnitude
        
        spriteLayer.add(animation, forKey: spriteAnimationKey)
    }
    
    /// Stops the animation and seeks to the beginning.
    public func stopAnimating() {
        spriteLayer.removeAnimation(forKey: spriteAnimationKey)
        resume()
    }
    
    /**
        Returns `true` when `startAnimating()` has been called without a subsequent call to `stopAnimating()`.
     
        - Note: Returns `true` even if the animation is paused.
     */
    public var isAnimating: Bool {
        return spriteLayer.animation(forKey: spriteAnimationKey) != nil
    }
    
    /// Stops the animation and jumps to the first frame.
    public func seekToBeginning() {
        stopAnimating()
        
        guard let sheetInfo = self.sheetInfo else { return }
        
        CATransaction.begin()
        defer { CATransaction.commit() }
        CATransaction.setDisableActions(true)
        
        spriteLayer.contentsRect = CGRect(
            x: 0,
            y: 0,
            width: 1,
            height: sheetInfo.singleFrameWidthInPercent)
    }
    
    /// Stops the animation and jumps to the last frame.
    public func seekToEnd() {
        stopAnimating()
        
        guard let sheetInfo = self.sheetInfo else { return }
        
        CATransaction.begin()
        defer { CATransaction.commit() }
        CATransaction.setDisableActions(true)
        
        spriteLayer.contentsRect = CGRect(
            x: 0,
            y: 1 - sheetInfo.singleFrameWidthInPercent,
            width: 1,
            height: sheetInfo.singleFrameWidthInPercent)
    }
    
    /// Pauses the animation at its current frame. Does nothing if the animation is already paused.
    public func pause() {
        guard !isPaused else { return }
        spriteLayer.pause()
    }
    
    /// Resumes the animation from the frame that was current when `pause()` was called. Does nothing if the animation is already playing.
    public func resume() {
        guard isPaused else { return }
        spriteLayer.resume()
    }
    
    /**
        Returns `true` when `pause()` has been called without either:
     
        * A subsequent call to `resume()`.
        * Any other change in the animation (e.g. `startAnimation()`, `stopAnimation()`, the `spriteImage` setter).
     */
    public var isPaused: Bool {
        return spriteLayer.speed == 0
    }
    
    public override func layoutSubviews() {
        spriteLayer.anchorPoint = .zero
        spriteLayer.bounds.size = bounds.size
        spriteLayer.position = .zero
    }
    
    public override var intrinsicContentSize: CGSize {
        guard let image = spriteSheet else { return super.intrinsicContentSize }
        let width = image.size.width
        return CGSize(width: width, height: width)
    }
}

private let spriteAnimationKey = "sprite"
