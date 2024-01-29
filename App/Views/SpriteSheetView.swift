//  SpriteSheetView.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Combine
import UIKit

/**
    An animation view that loads a sprite sheet.
 
    The sprite sheet is a single image with multiple frames stacked in a single column with no spacing in between.
 
    Animation is done by updating a `CALayer`'s `contentRect`.
 */
public final class SpriteSheetView: UIView {
    
    private var cancellables: Set<AnyCancellable> = []
    private var colorFollowsTheme = false
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
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
    // Optionally, provide a color to tint the
    public convenience init(
        spriteSheet: UIImage,
        followsTheme: Bool = false,
        tint color: UIColor? = nil
    ) {
        self.init(frame: CGRect(origin: .zero, size: spriteSheet.size))
        
        let chosenColor: UIColor?
        if followsTheme {
            chosenColor = Theme.defaultTheme()["tintColor"]
            colorFollowsTheme = true
        } else {
            chosenColor = color
        }

        if let tintColor = chosenColor, let spriteSheet = spriteSheet.withTint(tintColor) {
            self.spriteSheet = spriteSheet
        } else {
            self.spriteSheet = spriteSheet
        }
        
        if colorFollowsTheme {
            $darkMode
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if let currentSheet = self.spriteSheet,
                       let tintColor = Theme.defaultTheme()[color: "tintColor"],
                       let newSheet = currentSheet.withTint(tintColor)
                    {
                        self.spriteSheet = newSheet
                    }
                }
                .store(in: &cancellables)
        }
        
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
        animation.calculationMode = CAAnimationCalculationMode.discrete
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

private extension CALayer {

    /**
     Pauses all animations in the layer's tree.

     - Note: Calling `pause()` multiple times without intervening calls to `resume()` will probably not work as expected. `pause()` is not idempotent.
     - Warning: Calling `pause()` on the wrong layer can prevent iOS orientation change animations from working properly, causing your app to apparently freeze.
     - Seealso: "Technical Q&A QA1673" https://developer.apple.com/library/content/qa/qa1673/_index.html
     */
    func pause() {
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0
        timeOffset = pausedTime
    }

    /**
     Resumes all animations in the layer's tree after a prior call to `pause()`.

     - Note: Calling `resume()` multiple times without intervening calls to `pause()` will probably not work as expected. `resume()` is not idempotent.
     - Seealso: "Technical Q&A QA1673" https://developer.apple.com/library/content/qa/qa1673/_index.html
     */
    func resume() {
        let pausedTime = timeOffset
        speed = 1
        timeOffset = 0
        beginTime = 0
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        beginTime = timeSincePause
    }
}
