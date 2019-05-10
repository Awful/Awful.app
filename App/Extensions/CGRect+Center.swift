//  CGRect+Center.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}
