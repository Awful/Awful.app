//
//  ImageTinting.swift
//  Awful
//
//  Created by Liam Westby on 7/28/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation

class ImageTinting {
    // Consult https://stackoverflow.com/questions/5423210/how-do-i-change-a-partially-transparent-images-color-in-ios/20750373#20750373
    // for the original source for this algorithm
    public static func tintImage(_ image: UIImage, as color: UIColor) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width: Int = Int(image.scale * image.size.width)
        let height: Int = Int(image.scale * image.size.height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext.init(data: nil,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: 0,
                                     space: colorSpace,
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue)!
        
        context.clip(to: bounds, mask: cgImage)
        context.setFillColor(color.cgColor)
        context.fill(bounds)
        
        guard let imageBitmapContext = context.makeImage() else { return nil }
        return UIImage(cgImage: imageBitmapContext, scale: image.scale, orientation: UIImageOrientation.up)
    }
}
