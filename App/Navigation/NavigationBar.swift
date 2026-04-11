//  NavigationBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Long-tapping the back button of an AwfulNavigationBar will pop its navigation controller to its root view controller.
final class NavigationBar: UINavigationBar {

    private lazy var bottomBorder: HairlineView = {
        let bottomBorder = HairlineView()
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomBorder, constrainEdges: [.bottom, .left, .right])
        return bottomBorder
    }()

    var bottomBorderColor: UIColor? {
        get { return bottomBorder.backgroundColor }
        set { bottomBorder.backgroundColor = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // For whatever reason, translucent navbars with a barTintColor do not necessarily blur their backgrounds. An iPad 3, for example, blurs a bar without a barTintColor but is simply semitransparent with a barTintColor. The semitransparent, non-blur effect looks awful, so just turn it off.
        // iOS 26: Allow translucency for liquid glass effect
        if #available(iOS 26.0, *) {
            isTranslucent = true
        } else {
            isTranslucent = false
        }

        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        barStyle = .black
        
        backIndicatorImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        backIndicatorTransitionMaskImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        
        titleTextAttributes = [.font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)]
        
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPress)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// When set, `layoutSubviews` forces this color as `tintColor` and
    /// recolors all internal labels on every layout pass. Used by
    /// NavigationController for iPad sidebar where iOS 26 flat rendering
    /// ignores appearance APIs and colors elements with the app tintColor.
    var forcedTintColor: UIColor?

    private static let sidebarToggleOverlayTag = 9999

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let forced = forcedTintColor else { return }

        if tintColor != forced {
            tintColor = forced
        }

        // Force tintColor on every subview in the nav bar so the flat
        // rendering's buttons pick up the correct color regardless of
        // which view they inherit tintColor from.
        func forceTint(in view: UIView) {
            if view.tintColor != forced {
                view.tintColor = forced
            }
            // Also catch the system sidebar toggle: find SF Symbol images
            // with vibrancy rendering and overlay with .alwaysOriginal.
            // Skip our own replacement (identified by tag).
            if let imageView = view as? UIImageView,
               imageView.tag != Self.sidebarToggleOverlayTag,
               let image = imageView.image,
               image.isSymbolImage,
               !imageView.isHidden,
               String(describing: image).contains("sidebar.leading") {
                imageView.isHidden = true
                if let parent = imageView.superview,
                   parent.viewWithTag(Self.sidebarToggleOverlayTag) == nil {
                    let replacement = UIImageView(
                        image: UIImage(systemName: "sidebar.leading")?
                            .withTintColor(forced, renderingMode: .alwaysOriginal)
                    )
                    replacement.tag = Self.sidebarToggleOverlayTag
                    replacement.isUserInteractionEnabled = false
                    replacement.translatesAutoresizingMaskIntoConstraints = false
                    parent.addSubview(replacement)
                    NSLayoutConstraint.activate([
                        replacement.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
                        replacement.centerYAnchor.constraint(equalTo: parent.centerYAnchor),
                    ])
                }
            }
            for child in view.subviews {
                forceTint(in: child)
            }
        }
        forceTint(in: self)
    }

    @objc fileprivate func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        guard backItem != nil else { return }
        guard let nav = delegate as? UINavigationController else { return }
        
        // Try to find the back button's view without accessing its private `_view` ivar.
        guard let leftmost = subviews.lazy
            .filter({$0.bounds.width < self.bounds.width / 2})
            .min(by: {$0.frame.minX < $1.frame.minX || $0.bounds.width > $1.bounds.width}),
            leftmost.bounds.contains(sender.location(in: leftmost))
            else { return }
        nav.popToRootViewController(animated: true)
    }
}
