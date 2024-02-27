//  CGContext+.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics

// MARK: Save/restore state

public extension CGContext {
    func withGState(_ block: () -> Void) {
        saveGState()
        block()
        restoreGState()
    }
}
