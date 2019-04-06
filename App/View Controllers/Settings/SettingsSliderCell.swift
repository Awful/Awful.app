//  SettingsSliderCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import UIKit

class SettingsSliderCell : UITableViewCell {
    @IBOutlet weak var slider: UISlider!
    
    func setImageColor(_ color: UIColor) {
        if let minImage = slider.minimumValueImage {
            slider.minimumValueImage = minImage.withTint(color)
        }
        
        if let maxImage = slider.maximumValueImage {
            slider.maximumValueImage = maxImage.withTint(color)
        }
    }
}
