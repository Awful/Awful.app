//  SettingsSliderCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import UIKit

class SettingsSliderCell : UITableViewCell {
    @IBOutlet weak var slider: UISlider!
    
    func setImageColor(_ color: UIColor) {
        if let minImage = slider.minimumValueImage {
            slider.minimumValueImage = tintImage(minImage, as: color)
        }
        
        if let maxImage = slider.maximumValueImage {
            slider.maximumValueImage = tintImage(maxImage, as: color)
        }
    }
    
    private func tintImage(_ image: UIImage, as color: UIColor) -> UIImage? {
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
