//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

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

extension UITableViewCell {
    /// Gets/sets the background color of the selectedBackgroundView (inserting one if necessary).
    var selectedBackgroundColor: UIColor? {
        get {
            return selectedBackgroundView?.backgroundColor
        }
        set {
            if selectedBackgroundView == nil {
                selectedBackgroundView = UIView()
            }
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
