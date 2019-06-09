//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MobileCoreServices
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
    convenience init?(hex hexString: String) {
        let scanner = Scanner(string: hexString)
        _ = scanner.scan("#")
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
        func hexy(_ f: CGFloat) -> String {
            return String(lround(Double(f) * 255), radix: 16, uppercase: false)
        }
        return "#" + [red, green, blue].map(hexy).joined(separator: "")
    }
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
    - returns:
        A font associated with the text style, scaled for the user's Dynamic Type settings, in the requested font family.
    **/
    class func preferredFontForTextStyle(_ textStyle: TypedTextStyle, fontName: String? = nil, sizeAdjustment: CGFloat = 0) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFont.TextStyle(rawValue: textStyle.UIKitRawValue))
        if let fontName = fontName {
            return UIFont(name: fontName, size: descriptor.pointSize + sizeAdjustment)!
        } else {
            return UIFont(descriptor: descriptor, size: descriptor.pointSize + sizeAdjustment)
        }
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
    /// A replacement label for the title that shows two lines on iPhone.
    var titleLabel: UILabel {
        if let label = titleView as? UILabel { return label }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.textColor = .white
        label.accessibilityTraits.insert(UIAccessibilityTraits.header)
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

     /// Gets the first URL-like item on the pasteboard. A URL-like item is either a URL or a string that can be coerced into a URL.
    var coercedURL: URL? {
        get {
            if _hasURLs, let urls = urls, let url = urls.first {
                return url
            } else if _hasStrings, let strings = strings, let url = strings.compactMap({ URL(string: $0) }).first {
                return url
            } else {
                return nil
            }
        }
        set {
            items = newValue.map { [[
                kUTTypeURL as String: $0,
                kUTTypePlainText as String: $0.absoluteString]] }
            ?? []
        }
    }

    private var _hasStrings: Bool {
        if #available(iOS 10.0, *) {
            return hasStrings
        } else {
            return !(strings ?? []).isEmpty
        }
    }

    private var _hasURLs: Bool {
        if #available(iOS 10.0, *) {
            return hasURLs
        } else {
            return !(urls ?? []).isEmpty
        }
    }
}

extension UIScrollView {

    /// The scroll view's content offset as a proportion of the content size (where content size does not include any content inset).
    var fractionalContentOffset: CGPoint {
        return CGPoint(
            x: contentSize.width != 0 ? contentOffset.x / contentSize.width : 0,
            y: contentSize.height != 0 ? contentOffset.y / contentSize.height : 0)
    }
}

extension UISplitViewController {
    /// Animates the primary view controller into view if it is not already visible.
    func showPrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !isCollapsed, displayMode == .primaryHidden else { return }
        let button = displayModeButtonItem
        guard let target = button.target as? NSObject else { return }
        target.perform(button.action, with: nil)
    }
    
    /// Animates the primary view controller out of view if it is currently visible in an overlay.
    func hidePrimaryViewController() {
        // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
        guard !isCollapsed, displayMode == .primaryOverlay else { return }
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

    /**
     Replaces the `selectedRange` with `text` by modifying `textStorage` directly.

     This bypasses input traits and avoids text view contents jumping around after inserting an image.

     `Notification.Name.UITextViewTextDidChange` is manually posted while calling this method. I haven't tested whether `UITextViewDelegate` calls get made as a result of calling this method, but I would not be surprised if they are bypassed.

     - Seealso: rdar://problem/34617193 UITextView that isn't first responder ignores smartQuotesType when calling replace(_:withText:)
     */
    func replaceSelection(with text: String) {
        // If the text view is empty when mucking with text storage then the `font` and `textColor` properties are ignored.
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let font = font {
            attributes[.font] = font
        }
        if let textColor = textColor {
            attributes[.foregroundColor] = textColor
        }

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: selectedRange, with: NSAttributedString(string: text, attributes: attributes))
        textStorage.endEditing()

        // Mucking with text storage does not send this notification automatically, but we'd like this notification to be sent.
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)

        selectedRange = NSRange(location: selectedRange.location + text.utf16.count, length: 0)
    }

    /// Returns a rectangle that encompasses the current selection in the text view, or nil if there is no selection.
    var selectedRect: CGRect? {
        switch selectedTextRange {
        case .some(let selection) where selection.isEmpty:
            return caretRect(for: selection.end)
        case .some(let selection):
            let rects = selectionRects(for: selection).map { ($0 ).rect }
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

extension Sequence where Element == NSLayoutConstraint {
    func activate() {
        forEach { $0.isActive = true }
    }
}

extension UIView {
    func constrain(to view: UIView, edges: UIRectEdge, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        if edges.contains(.top) {
            constraints.append(topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top))
        }
        if edges.contains(.bottom) {
            constraints.append(view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom))
        }
        if edges.contains(.left) {
            constraints.append(leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left))
        }
        if edges.contains(.right) {
            constraints.append(view.rightAnchor.constraint(equalTo: rightAnchor, constant: insets.right))
        }
        return constraints
    }
    
    func addSubview(_ subview: UIView, constrainEdges edges: UIRectEdge, insets: UIEdgeInsets = .zero) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        subview.constrain(to: self, edges: edges, insets: insets).activate()
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
    /**
     Basically `childViewControllers` plus:
     
         * The presented view controller, if any.
         * Any currently hidden view controllers if this is one of the common container view controllers (e.g. `UITabBarController` tabs that are not the current tab).
     */
    var immediateDescendants: [UIViewController] {
        var immediateDescendants: [UIViewController] = []
        var alreadyAdded: Set<UIViewController> = []
        
        let add = { (vc: UIViewController) in
            guard !alreadyAdded.contains(vc) else { return }
            immediateDescendants.append(vc)
            alreadyAdded.insert(vc)
        }
        
        if let presented = presentedViewController {
            add(presented)
        }
        
        children.forEach(add)
        
        switch self {
        case let nav as UINavigationController:
            nav.viewControllers.forEach(add)
        case let split as UISplitViewController:
            split.viewControllers.forEach(add)
        case let tab as UITabBarController:
            tab.viewControllers?.forEach(add)
        default:
            break
        }
        
        return immediateDescendants
    }
    
    var subtree: AnySequence<UIViewController> {
        return AnySequence { () -> AnyIterator<UIViewController> in
            var viewControllers: [UIViewController] = [self]

            return AnyIterator {
                guard !viewControllers.isEmpty else { return nil }
                let vc = viewControllers.removeFirst()

                viewControllers.insert(contentsOf: vc.immediateDescendants, at: 0)
                
                return vc
            }
        }
    }

    func firstDescendantOfType<VC: UIViewController>(_ type: VC.Type) -> VC? {
        for vc in subtree {
            if let vc = vc as? VC {
                return vc
            }
        }
        return nil
    }
}
