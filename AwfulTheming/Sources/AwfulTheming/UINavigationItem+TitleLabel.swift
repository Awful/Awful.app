//  UINavigationItem+TitleLabel.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// The label `UINavigationItem.titleLabel` puts in the bar. On iPhone it shows two smaller lines. On iPad it shows one larger line, except in a window narrow enough to be compact width, where it takes the iPhone style, restyling itself as the window resizes.
public final class NavigationTitleLabel: UILabel {

    /// The theme the post title font sizes and weights come from.
    public var theme: Theme = .defaultTheme() {
        didSet { updateStyle() }
    }

    /// Keeps the title to one line sized to its text, so the bar centres it like the system title.
    public var fitsToText = false {
        didSet { updateStyle() }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            updateStyle()
        }
    }

    fileprivate func updateStyle() {
        // The device decides first, so an iPhone keeps its style even where it's regular width (a large iPhone in landscape, the unfolded iPhone Duo). A size class that isn't known yet, before the label is in a window, counts as wide.
        let usesPadStyle = UIDevice.current.userInterfaceIdiom == .pad && traitCollection.horizontalSizeClass != .compact
        let keySuffix = usesPadStyle ? "Pad" : "Phone"
        let sizeAdjustment = theme[double: "postTitleFontSizeAdjustment\(keySuffix)"] ?? (usesPadStyle ? 0 : -1)
        let weight = theme["postTitleFontWeight\(keySuffix)"].flatMap(FontWeight.init(rawValue:))?.weight ?? .semibold
        font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: sizeAdjustment, weight: weight)
        numberOfLines = fitsToText || usesPadStyle ? 1 : 2
        if fitsToText {
            sizeToFit()
        }
    }
}

public extension UINavigationItem {
    /// A replacement label for the title, two lines on iPhone and in a narrow iPad window (see `NavigationTitleLabel`). The web-content screens (posts, a message, the rap sheet) colour it through `updateTitleLabelTextColor` as the iOS 26 glass bar goes transparent. The system title is coloured by the navigation controller's appearance instead.
    var titleLabel: NavigationTitleLabel {
        let label: NavigationTitleLabel = (titleView as? NavigationTitleLabel) ?? {
            let label = NavigationTitleLabel(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            label.textAlignment = .center
            label.textColor = label.theme["navigationBarTextColor"]!
            label.accessibilityTraits.insert(.header)
            label.updateStyle()
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
    /// `contentColor` is the colour `ContentContrastSampler` measured beneath the title (the
    /// posts page in immersive mode; the system won't adapt a title the way it does its glass
    /// bar buttons — see that class); nil falls back to the theme's mode colour.
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
