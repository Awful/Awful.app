//  UIImage+Decompression.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIImage {

    /**
     Returns a copy of this image that's ready for display without further processing. If that's not possible, the receiver is returned instead.

     This can be useful to run on a background queue. Take the returned image back to the main queue and it's ready for immediate display.
     */
    func makeDecompressedCopy() -> UIImage {

        // This is wholly ripped off from a Nuke internal function. Unfortunately there's seemingly no way to use it (directly or indirectly) without running through an entire `ImagePipeline`, so it's copypasta time.

        guard let cgImage = cgImage else { return self }

        // For more info see:
        // - Quartz 2D Programming Guide
        // - https://github.com/kean/Nuke/issues/35
        // - https://github.com/kean/Nuke/issues/57
        let alphaInfo: CGImageAlphaInfo = cgImage.isOpaque ? .noneSkipLast : .premultipliedLast

        guard let ctx = CGContext(
            data: nil,
            width: cgImage.width, height: cgImage.height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alphaInfo.rawValue)
            else { return self }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        guard let decompressed = ctx.makeImage() else { return self }
        return UIImage(cgImage: decompressed, scale: scale, orientation: imageOrientation)
    }
}
