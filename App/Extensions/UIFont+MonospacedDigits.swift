//  UIFont+MonospacedDigits.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// https://stackoverflow.com/a/30981587 Thanks!

extension UIFont {
    var monospacedDigitFont: UIFont {
        return UIFont(descriptor: fontDescriptor.monospacedDigitDescriptor, size: 0)
    }
}

extension UIFontDescriptor {
    var monospacedDigitDescriptor: UIFontDescriptor {
        let featureSettings = [[UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                                .typeIdentifier: kMonospacedNumbersSelector]]
        return addingAttributes([.featureSettings: featureSettings])
    }
}
