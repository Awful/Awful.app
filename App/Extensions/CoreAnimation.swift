//  CoreAnimation.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import QuartzCore

extension CALayer {
    
    /**
     Pauses all animations in the layer's tree.
     
     - Note: Calling `pause()` multiple times without intervening calls to `resume()` will probably not work as expected. `pause()` is not idempotent.
     - Warning: Calling `pause()` on the wrong layer can prevent iOS orientation change animations from working properly, causing your app to apparently freeze.
     - Seealso: "Technical Q&A QA1673" https://developer.apple.com/library/content/qa/qa1673/_index.html
     */
    internal func pause() {
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0
        timeOffset = pausedTime
    }
    
    /**
     Resumes all animations in the layer's tree after a prior call to `pause()`.
     
     - Note: Calling `resume()` multiple times without intervening calls to `pause()` will probably not work as expected. `resume()` is not idempotent.
     - Seealso: "Technical Q&A QA1673" https://developer.apple.com/library/content/qa/qa1673/_index.html
     */
    internal func resume() {
        let pausedTime = timeOffset
        speed = 1
        timeOffset = 0
        beginTime = 0
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        beginTime = timeSincePause
    }
}
