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

public func roundedFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont {
    // Will be SF Compact or standard SF in case of failure.
    if let descriptor = UIFont.systemFont(ofSize: fontSize, weight: weight).fontDescriptor.withDesign(.rounded) {
        return UIFont(descriptor: descriptor, size: fontSize)
    } else {
        return UIFont.systemFont(ofSize: fontSize, weight: weight)
    }
}
