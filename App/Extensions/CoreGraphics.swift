//  CoreGraphics.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics

extension CGContext {
    func withGState(_ block: () -> Void) {
        saveGState()
        block()
        restoreGState()
    }
}

extension CGFloat {
    func clamp(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        return Swift.max(Swift.min(self, high), low)
    }
}
