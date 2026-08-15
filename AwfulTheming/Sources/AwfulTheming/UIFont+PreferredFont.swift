//  UIFont+PreferredFont.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIFont {
    /**
     - parameters:
     - textStyle: The base style for the returned font.
     - fontName: An optional font name. If nil (the default), returns the system font.
     - sizeAdjustment: A positive or negative adjustment to apply to the text style's font size. The default is 0.
     - weight: A positive or negative adjustment to apply to the text style's font size. The default is 0.
     - returns:
     A font associated with the text style, scaled for the user's Dynamic Type settings, in the requested font family.
     **/
    public class func preferredFontForTextStyle(_ textStyle: TextStyle, fontName: String? = nil, sizeAdjustment: CGFloat = 0, weight: UIFont.Weight, for traitCollection: UITraitCollection? = nil) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])

        let metrics = UIFontMetrics(forTextStyle: textStyle)

        // set a maximum font size of 30pt
        var font = metrics.scaledFont(for: UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment), maximumPointSize: 30, compatibleWith: traitCollection)

        // overwrite these to effectively set a minimum font size, regardless of user's dynamic type setting
        switch UIApplication.shared.preferredContentSizeCategory {
        case .extraSmall, .small, .medium:
            font = metrics.scaledFont(for: UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment), maximumPointSize: 30, compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraLarge))
        case .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            font = metrics.scaledFont(for: UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment), maximumPointSize: 30, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityLarge))
        default:
            font = metrics.scaledFont(for: UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment), maximumPointSize: 30, compatibleWith: UITraitCollection(preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory))
        }

        if let fontName = fontName, let customFont = UIFont(name: fontName, size: descriptor.pointSize + sizeAdjustment) {
            font = metrics.scaledFont(for: customFont, maximumPointSize: 30, compatibleWith: traitCollection)
        } else {
            if let descriptor = font.fontDescriptor.withDesign(.rounded) {
                if Theme.defaultTheme().roundedFonts {
                    font = metrics.scaledFont(for: UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment), maximumPointSize: 30, compatibleWith: traitCollection)
                }
            }
        }

        return font
    }
}
