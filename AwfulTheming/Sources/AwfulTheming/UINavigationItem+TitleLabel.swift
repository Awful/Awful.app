//  UINavigationItem+TitleLabel.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UINavigationItem {
    /// A replacement label for the title that shows two lines on iPhone. Screens whose title
    /// colour follows the page beneath the iOS 26 glass bar (posts, a message, the rap sheet)
    /// colour it through `updateTitleLabelTextColor`; the system title is coloured by the
    /// navigation controller's appearance instead.
    var titleLabel: UILabel {
        let label: UILabel = (titleView as? UILabel) ?? {
            let theme = Theme.defaultTheme()
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            label.textAlignment = .center
            label.textColor = theme["navigationBarTextColor"]!
            label.accessibilityTraits.insert(.header)
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                label.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPad"]!)!.weight)
            default:
                label.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPhone"]!)!.weight)
                label.numberOfLines = 2
            }
            return label
        }()
        // Sometimes the titleView is removed from the navigation bar. Seems related to the app moving to/from the background? Its superview becomes `nil` even though it's still the navigation item's `titleView`. Simply setting `titleView` again isn't enough in that scenario, we need to `nil` it out first.
        if label.superview == nil {
            titleView = nil
        }
        // Re-assigning the same instance re-hosts it, and this getter runs on every scroll
        // event on iOS 26.
        if titleView !== label {
            titleView = label
        }
        return label
    }

    /// Keeps `titleLabel` readable as the iOS 26 Liquid Glass bar goes from the opaque theme
    /// background (at the top) to transparent (once scrolled), matching the bar buttons.
    /// Thresholds rather than exact 0/1 avoid flicker from tiny offset adjustments.
    ///
    /// `contentColor` is the colour `NavigationBarTitleContrastSampler` measured beneath the
    /// title (the system won't adapt a title the way it does its glass bar buttons — see that
    /// class); nil falls back to the theme's mode colour.
    func updateTitleLabelTextColor(forScrollProgress progress: CGFloat, theme: Theme, contentColor: UIColor? = nil) {
        // Reduce Liquid Glass keeps the bar solid at every offset, so the title keeps the
        // theme's bar text colour rather than following the scroll into the content's.
        let progress = LiquidGlass.isEnabled ? progress : 0
        if progress < 0.01 {
            titleLabel.textColor = theme[uicolor: "navigationBarTextColor"] ?? .label
        } else if progress > 0.99 {
            titleLabel.textColor = contentColor ?? theme.glassContentTextColor
        }
    }
}
