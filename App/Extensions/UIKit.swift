//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIBarButtonItem {
    /// Returns a UIBarButtonItem of type UIBarButtonSystemItemFlexibleSpace configured with no target.
    class func flexibleSpace() -> Self {
        return self.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }
    
    /// Returns a UIBarButtonItem of type UIBarButtonSystemItemFixedSpace.
    class func fixedSpace(_ width: CGFloat) -> Self {
        let item = self.init(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        item.width = width
        return item
    }
    
    var actionBlock: ((UIBarButtonItem) -> Void)? {
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
    let block: (UIBarButtonItem) -> Void
    init(_ block: @escaping (UIBarButtonItem) -> Void) { self.block = block }
    @objc func invoke(_ sender: UIBarButtonItem) { block(sender) }
}

private var actionBlockKey = 0

extension UIColor {
    // Making this a failable convenience initializer causes a crash in Xcode 7.3 (Swift 2.2, iOS 9.3) when bailing out early (i.e. when scanHex() fails).
    class func fromHex(_ hexCode: String) -> UIColor? {
        let scanner = Scanner(string: hexCode)
        _ = scanner.scan("#")
        let start = scanner.scanLocation
        guard let hex = scanner.scanHex() else { return nil }
        let length = scanner.scanLocation - start
        switch length {
        case 3:
            return UIColor(
                red: CGFloat((hex & 0xF00) >> 8) / 15,
                green: CGFloat((hex & 0x0F0) >> 4) / 15,
                blue: CGFloat((hex & 0x00F) >> 0) / 15,
                alpha: 1)
        case 4:
            return UIColor(
                red: CGFloat((hex & 0xF000) >> 12) / 15,
                green: CGFloat((hex & 0x0F00) >> 8) / 15,
                blue: CGFloat((hex & 0x00F0) >> 4) / 15,
                alpha: CGFloat((hex & 0x000F) >> 0) / 15)
        case 6:
            return UIColor(
                red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                blue: CGFloat((hex & 0x0000FF) >> 0) / 255,
                alpha: 1)
        case 8:
            return UIColor(
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
        func hexy(_ f: CGFloat) -> String {
            return String(lround(Double(f) * 255), radix: 16, uppercase: false)
        }
        return "#" + [red, green, blue].map(hexy).joined(separator: "")
    }
}

extension UIFont {
    /// Typed versions of the `UIFontTextStyle*` constants.
    enum TextStyle {
        case body, footnote, caption1
        
        var UIKitRawValue: String {
            switch self {
            case .body: return UIFontTextStyle.body.rawValue
            case .footnote: return UIFontTextStyle.footnote.rawValue
            case .caption1: return UIFontTextStyle.caption1.rawValue
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
    class func preferredFontForTextStyle(_ textStyle: TextStyle, fontName: String? = nil, sizeAdjustment: CGFloat = 0) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle(rawValue: textStyle.UIKitRawValue))
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
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.textColor = .white
        label.accessibilityTraits |= UIAccessibilityTraitHeader
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            label.font = UIFont.systemFont(ofSize: 17)
        default:
            label.font = UIFont.systemFont(ofSize: 13)
            label.numberOfLines = 2
        }
        titleView = label
        return label
    }
}

extension UIPasteboard {
    /// Some (system) apps seem to put actual NSURLs on the pasteboard, while others deal in strings that happen to resemble URLs. This property handles both.
    var awful_URL: URL? {
        get {
            if let URL = url { return URL }
            if let string = string { return URL(string: string) }
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
        guard !isCollapsed else { return }
        guard displayMode == .primaryHidden else { return }
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
    
    /// Animates the primary view controller out of view if it is currently visible in an overlay.
    func hidePrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !isCollapsed else { return }
        guard displayMode == .primaryOverlay else { return }
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
}

extension UITableView {
    /// Stops the table view from showing any cell separators after the last cell.
    func hideExtraneousSeparators() {
        tableFooterView = UIView()
    }
    
    /// Causes the section headers not to stick to the top of a table view.
    func unstickSectionHeaders() {
        let headerFrame = CGRect(x: 0, y: 0, width: 0, height: sectionHeaderHeight * 2)
        tableHeaderView = UIView(frame: headerFrame)
        contentInset.top -= headerFrame.height
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
        case .some(let selection) where selection.isEmpty:
            return caretRect(for: selection.end)
        case .some(let selection):
            let rects = selectionRects(for: selection).map { ($0 as! UITextSelectionRect).rect }
            if rects.isEmpty {
                return nil
            } else {
                return rects.reduce { $0.union($1) }
            }
        case .none:
            return nil
        }
    }
}

extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder?.next
            if let vc = responder as? UIViewController { return vc }
        }
        return nil
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

extension UIViewController {
    func firstDescendantOfType<VC: UIViewController>(_ type: VC.Type) -> VC? {
        if let found = self as? VC { return found }
        if responds(to: #selector(getter: UINavigationController.viewControllers)) {
            for child in value(forKey: "viewControllers") as! [UIViewController] {
                if let found = child.firstDescendantOfType(type) {
                    return found
                }
            }
        }
        return nil
    }
    
    // objc version
    func firstDescendantOfClass(_ cls: AnyClass) -> AnyObject? {
        if isKind(of: cls) { return self }
        if responds(to: #selector(getter: UINavigationController.viewControllers)) {
            for child in value(forKey: "viewControllers") as! [UIViewController] {
                if let found = child.firstDescendantOfClass(cls) {
                    return found
                }
            }
        }
        return nil
    }
}

extension UIWebView {
    /// The percentage of the web view that's been scrolled down. Potentially more helpful than contentOffset when aiming for orientation indepdence.
    var fractionalContentOffset: CGFloat {
        get {
            guard let
                result = stringByEvaluatingJavaScript(from: "document.body.scrollTop / document.body.scrollHeight"),
                let offset = Double(result)
                else { return 0 }
            return CGFloat(offset)
        }
        set {
            stringByEvaluatingJavaScript(from: "window.scroll(0, document.body.scrollHeight * \(newValue)")
        }
    }
    
    /// Creates and returns a UIWebView suitable for displaying native content.
    class func nativeFeelingWebView() -> Self {
        let webView = self.init()
        webView.scalesPageToFit = true
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.dataDetectorTypes = UIDataDetectorTypes()
        webView.isOpaque = false
        return webView
    }
    
    /**
        - parameter rectString: A string, formatted appropriately for CGRectFromString, representing the element's client bounding rect.
     
        - returns: A rect in the web view's coordinate system corresponding to an element's offset.
     */
    func rectForElementBoundingRect(_ rectString: String) -> CGRect {
        return CGRectFromString(rectString).insetBy(dx: scrollView.contentInset.left, dy: scrollView.contentInset.top)
    }
}
