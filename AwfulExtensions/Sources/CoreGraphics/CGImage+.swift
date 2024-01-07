//  CGImage+.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics

// MARK: Is opaque?

public extension CGImage {

    /// `true` when the image's `alphaInfo` indicates there is no alpha info.
    var isOpaque: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return true
        case .premultipliedLast, .premultipliedFirst, .last, .first, .alphaOnly:
            return false
        @unknown default:
            assertionFailure("handle unknown alpha info")
            return false
        }
    }
}
