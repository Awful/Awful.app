//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit

extension CGRect {
    var pixelRound: CGRect {
        var rounded = self
        rounded.origin.x = Awful.pixelRound(rounded.origin.x)
        rounded.origin.y = Awful.pixelRound(rounded.origin.y)
        rounded.size = size.pixelCeil
        return rounded
    }
}

extension CGSize {
    var pixelCeil: CGSize {
        return CGSize(width: Awful.pixelCeil(width), height: Awful.pixelCeil(height))
    }
}

private let defaultScale: CGFloat = UIScreen.main.scale

func pixelCeil(_ val: CGFloat, scale: CGFloat = defaultScale) -> CGFloat {
    return ceil(val * scale) / scale
}

func pixelRound(_ val: CGFloat, scale: CGFloat = defaultScale) -> CGFloat {
    return round(val * scale) / scale
}

extension UIFont {
    /// Typed versions of the `UIFontTextStyle*` constants.
    enum TypedTextStyle {
        case body, footnote, caption1
        
        var UIKitRawValue: String {
            switch self {
            case .body: return UIFont.TextStyle.body.rawValue
            case .footnote: return UIFont.TextStyle.footnote.rawValue
            case .caption1: return UIFont.TextStyle.caption1.rawValue
            }
        }
    }
    
    /**
     - parameters:
     - textStyle: The base style for the returned font.
     - fontName: An optional font name. If nil (the default), returns the system font.
     - sizeAdjustment: A positive or negative adjustment to apply to the text style's font size. The default is 0.
     - weight: A positive or negative adjustment to apply to the text style's font size. The default is 0.
     - returns:
     A font associated with the text style, scaled for the user's Dynamic Type settings, in the requested font family.
     **/
    class func preferredFontForTextStyle(_ textStyle: TextStyle, fontName: String? = nil, sizeAdjustment: CGFloat = 0, weight: UIFont.Weight, for traitCollection: UITraitCollection? = nil) -> UIFont {
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
        
        if let fontName = fontName {
            font = metrics.scaledFont(for: UIFont(name: fontName, size: descriptor.pointSize + sizeAdjustment)!, maximumPointSize: 30, compatibleWith: traitCollection)
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

extension UIImage {
    /// Tint an image with a specific UIColor
    // Consult https://stackoverflow.com/questions/5423210/how-do-i-change-a-partially-transparent-images-color-in-ios/20750373#20750373
    // for the original source for this algorithm
    public func withTint(_ color: UIColor) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width: Int = Int(self.scale * self.size.width)
        let height: Int = Int(self.scale * self.size.height)
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
        return UIImage(cgImage: imageBitmapContext, scale: self.scale, orientation: UIImage.Orientation.up)
    }
}

extension UINavigationItem {
    // MARK: THREAD TITLE Posts View
    /// A replacement label for the title that shows two lines on iPhone.
    var titleLabel: UILabel {
        let theme = Theme.defaultTheme()
        if let label = titleView as? UILabel { return label }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.textColor = theme["navigationBarTextColor"]!
        label.accessibilityTraits.insert(UIAccessibilityTraits.header)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            label.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPad"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPad"]!)!.weight)
        default:
            label.font = UIFont.preferredFontForTextStyle(.callout, fontName: nil, sizeAdjustment: theme[double: "postTitleFontSizeAdjustmentPhone"]!, weight: FontWeight(rawValue: theme["postTitleFontWeightPhone"]!)!.weight)
            label.numberOfLines = 2
        }
        titleView = label
        return label
    }
}

extension UIPasteboard {

     /// Gets the first URL-like item on the pasteboard. A URL-like item is either a URL or a string that can be coerced into a URL.
    var coercedURL: URL? {
        get {
            if hasURLs, let url = urls?.first {
                return url
            } else if hasStrings, let url = strings?.lazy.compactMap({ URL(string: $0) }).first(where: { _ in true }) {
                return url
            } else {
                return nil
            }
        }
        set {
            string = newValue?.absoluteString
        }
    }
}

extension UISplitViewController {
    /// Animates the primary view controller into view if it is not already visible.
    func showPrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !isCollapsed, displayMode == .secondaryOnly else { return }
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
    
    /// Animates the primary view controller out of view if it is currently visible in an overlay.
    func hidePrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !isCollapsed, displayMode == .oneOverSecondary else { return }
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
}

extension UITableView {
    /// Causes the section headers not to stick to the top of a table view.
    func unstickSectionHeaders() {
        let headerFrame = CGRect(x: 0, y: 0, width: 0, height: sectionHeaderHeight * 2)
        tableHeaderView = UIView(frame: headerFrame)
        contentInset.top -= headerFrame.height
    }
}

extension UIViewController {
    /// Returns the view controller's navigation controller, lazily creating a NavigationController if needed. Created navigation controllers adopt the modalPresentationStyle of the view controller.
    var enclosingNavigationController: UINavigationController {
        if let nav = navigationController { return nav }
        let nav = NavigationController(rootViewController: self)
        nav.modalPresentationStyle = modalPresentationStyle
        if let identifier = restorationIdentifier {
            nav.restorationIdentifier = "\(identifier) navigation"
        }
        return nav
    }
}

public extension UIImage {
    /**
    Returns the flat colorized version of the image, or self when something was wrong
    - Parameters:
        - color: The colors to user. By defaut, uses the ``UIColor.white`
    - Returns: the flat colorized version of the image, or the self if something was wrong
    */
    private func colorized(with color: UIColor = .white) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        defer {
            UIGraphicsEndImageContext()
        }

        guard let context = UIGraphicsGetCurrentContext(), let cgImage = cgImage else { return self }


        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        color.setFill()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.clip(to: rect, mask: cgImage)
        context.fill(rect)

        guard let colored = UIGraphicsGetImageFromCurrentImageContext() else { return self }

        return colored
    }
    
    // combine two images layering top over bottom
    func mergeWith(topImage: UIImage) -> UIImage {
      let bottomImage = self
      
      UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

      let areaSize = CGRect(x: 0, y: 0, width: bottomImage.size.width, height: bottomImage.size.height)
      bottomImage.draw(in: areaSize)

      topImage.draw(in: areaSize, blendMode: .normal, alpha: 1.0)

      let mergedImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return mergedImage
    }
    
    /**
    Returns the stroked version of the fransparent image with the given stroke color and the thickness.
    - Parameters:
        - color: The colors to user. By defaut, uses the ``UIColor.white`
        - thickness: the thickness of the border. Default to `2`
        - quality: The number of degrees (out of 360): the smaller the best, but the slower. Defaults to `10`.
    - Returns: the stroked version of the image, or self if something was wrong
    */
    func stroked(with color: UIColor = .white, thickness: CGFloat = 2, quality: CGFloat = 10) -> UIImage {

        guard let cgImage = cgImage else { return self }

        // Colorize the stroke image to reflect border color
        let strokeImage = colorized(with: color)

        guard let strokeCGImage = strokeImage.cgImage else { return self }

        /// Rendering quality of the stroke
        let step = quality == 0 ? 10 : abs(quality)

        let oldRect = CGRect(x: thickness, y: thickness, width: size.width, height: size.height).integral
        let newSize = CGSize(width: size.width + 2 * thickness, height: size.height + 2 * thickness)
        let translationVector = CGPoint(x: thickness, y: 0)


        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)

        guard let context = UIGraphicsGetCurrentContext() else { return self }

        defer {
            UIGraphicsEndImageContext()
        }
        context.translateBy(x: 0, y: newSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.interpolationQuality = .high

        for angle: CGFloat in stride(from: 0, to: 360, by: step) {
            let vector = translationVector.rotated(around: .zero, byDegrees: angle)
            let transform = CGAffineTransform(translationX: vector.x, y: vector.y)

            context.concatenate(transform)

            context.draw(strokeCGImage, in: oldRect)

            let resetTransform = CGAffineTransform(translationX: -vector.x, y: -vector.y)
            context.concatenate(resetTransform)
        }

        context.draw(cgImage, in: oldRect)

        guard let stroked = UIGraphicsGetImageFromCurrentImageContext() else { return self }

        return stroked
    }
}


private extension CGPoint {
    /**
    Rotates the point from the center `origin` by `byDegrees` degrees along the Z axis.
    - Parameters:
        - origin: The center of he rotation;
        - byDegrees: Amount of degrees to rotate around the Z axis.
    - Returns: The rotated point.
    */
    func rotated(around origin: CGPoint, byDegrees: CGFloat) -> CGPoint {
        let dx = x - origin.x
        let dy = y - origin.y
        let radius = sqrt(dx * dx + dy * dy)
        let azimuth = atan2(dy, dx) // in radians
        let newAzimuth = azimuth + byDegrees * .pi / 180.0 // to radians
        let x = origin.x + radius * cos(newAzimuth)
        let y = origin.y + radius * sin(newAzimuth)
        return CGPoint(x: x, y: y)
    }
}
