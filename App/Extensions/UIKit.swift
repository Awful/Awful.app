//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIBarButtonItem {
    /// Returns a UIBarButtonItem of type UIBarButtonSystemItemFlexibleSpace configured with no target.
    class func flexibleSpace() -> Self {
        return self.init(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    }
    
    /// Returns a UIBarButtonItem of type UIBarButtonSystemItemFixedSpace.
    class func fixedSpace(width: CGFloat) -> Self {
        let item = self.init(barButtonSystemItem: .FixedSpace, target: nil, action: nil)
        item.width = width
        return item
    }
    
    var actionBlock: (UIBarButtonItem -> Void)? {
        get {
            guard let wrapper = objc_getAssociatedObject(self, &actionBlockKey) as? BlockWrapper else { return nil }
            return wrapper.block
        }
        set {
            guard let block = newValue else {
                target = nil
                action = nil
                return objc_setAssociatedObject(self, &actionBlockKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            let wrapper = BlockWrapper(block)
            target = wrapper
            action = #selector(BlockWrapper.invoke(_:))
            objc_setAssociatedObject(self, &actionBlockKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private class BlockWrapper {
    let block: UIBarButtonItem -> Void
    init(_ block: UIBarButtonItem -> Void) { self.block = block }
    @objc func invoke(sender: UIBarButtonItem) { block(sender) }
}

private var actionBlockKey = 0

extension UIColor {
    convenience init?(hexCode: String) {
        let scanner = NSScanner(string: hexCode)
        scanner.scan(string: "#")
        let start = scanner.scanLocation
        guard let hex = scanner.scanHex() else { return nil }
        let length = scanner.scanLocation - start
        switch length {
        case 3:
            self.init(
                red: CGFloat((hex & 0xF00) >> 8) / 15,
                green: CGFloat((hex & 0x0F0) >> 4) / 15,
                blue: CGFloat((hex & 0x00F) >> 0) / 15,
                alpha: 1)
        case 4:
            self.init(
                red: CGFloat((hex & 0xF000) >> 12) / 15,
                green: CGFloat((hex & 0x0F00) >> 8) / 15,
                blue: CGFloat((hex & 0x00F0) >> 4) / 15,
                alpha: CGFloat((hex & 0x000F) >> 0) / 15)
        case 6:
            self.init(
                red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                blue: CGFloat((hex & 0x0000FF) >> 0) / 255,
                alpha: 1)
        case 8:
            self.init(
                red: CGFloat((hex & 0xFF000000) >> 24) / 255,
                green: CGFloat((hex & 0x00FF0000) >> 16) / 255,
                blue: CGFloat((hex & 0x0000FF00) >> 8) / 255,
                alpha: CGFloat((hex & 0x000000FF) >> 0) / 255)
        default:
            return nil
        }
    }
    
    var hexCode: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "" }
        func hexy(f: CGFloat) -> String {
            return String(lround(Double(f) * 255), radix: 16, uppercase: false)
        }
        return "#" + [red, green, blue].map(hexy).joinWithSeparator("")
    }
}

extension UIFont {
    /// Typed versions of the `UIFontTextStyle*` constants.
    enum TextStyle {
        case Body, Footnote, Caption1
        
        var UIKitRawValue: String {
            switch self {
            case .Body: return UIFontTextStyleBody
            case .Footnote: return UIFontTextStyleFootnote
            case .Caption1: return UIFontTextStyleCaption1
            }
        }
    }
    
    /**
    - parameters:
        - textStyle: The base style for the returned font.
        - fontName: An optional font name. If nil (the default), returns the system font.
        - sizeAdjustment: A positive or negative adjustment to apply to the text style's font size. The default is 0.
    - returns:
        A font associated with the text style, scaled for the user's Dynamic Type settings, in the requested font family.
    **/
    class func preferredFontForTextStyle(textStyle: TextStyle, fontName: String? = nil, sizeAdjustment: CGFloat = 0) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(textStyle.UIKitRawValue)
        if let fontName = fontName {
            return UIFont(name: fontName, size: descriptor.pointSize + sizeAdjustment)!
        } else {
            return UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment)
        }
    }
}

extension UINavigationItem {
    /// A replacement label for the title that shows two lines on iPhone.
    var titleLabel: UILabel {
        if let label = titleView as? UILabel { return label }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
        label.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        label.textAlignment = .Center
        label.textColor = .whiteColor()
        label.accessibilityTraits |= UIAccessibilityTraitHeader
        switch UIDevice.currentDevice().userInterfaceIdiom {
        case .Pad:
            label.font = UIFont.systemFontOfSize(17)
        default:
            label.font = UIFont.systemFontOfSize(13)
            label.numberOfLines = 2
        }
        titleView = label
        return label
    }
}

extension UIPasteboard {
    /// Some (system) apps seem to put actual NSURLs on the pasteboard, while others deal in strings that happen to resemble URLs. This property handles both.
    var awful_URL: NSURL? {
        get {
            if let URL = URL { return URL }
            if let string = string { return NSURL(string: string) }
            return nil
        }
        set {
            items = []
            guard let newURL = newValue else { return }
            items = [[
                kUTTypeURL as String: newURL,
                kUTTypePlainText as String: newURL.absoluteString]]
        }
    }
}

extension UISplitViewController {
    /// Animates the primary view controller into view if it is not already visible.
    func showPrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !collapsed else { return }
        guard displayMode == .PrimaryHidden else { return }
        let button = displayModeButtonItem()
        guard let target = button.target as? NSObject else { return }
        target.performSelector(button.action, withObject: nil)
    }
    
    /// Animates the primary view controller out of view if it is currently visible in an overlay.
    func hidePrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard collapsed else { return }
        guard displayMode == .PrimaryOverlay else { return }
        let button = displayModeButtonItem()
        guard let target = button.target as? NSObject else { return }
        target.performSelector(button.action, withObject: nil)
    }
}

extension UITableViewCell {
    /// Gets/sets the background color of the selectedBackgroundView (inserting one if necessary).
    var selectedBackgroundColor: UIColor? {
        get {
            return selectedBackgroundView?.backgroundColor
        }
        set {
            selectedBackgroundView = UIView()
            selectedBackgroundView?.backgroundColor = newValue
        }
    }
}

extension UITextView {
    /// Returns a rectangle that encompasses the current selection in the text view, or nil if there is no selection.
    var selectedRect: CGRect? {
        switch selectedTextRange {
        case .Some(let selection) where selection.empty:
            return caretRectForPosition(selection.end)
        case .Some(let selection):
            let rects = selectionRectsForRange(selection).map { $0.rect }
            if rects.isEmpty {
                return nil
            } else {
                return rects.reduce(CGRect.null) { $0.union($1) }
            }
        case .None:
            return nil
        }
    }
}
