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
        isTranslucent = false
        var font: UIFont
        if Theme.defaultTheme().roundedFonts {
            font = roundedFont(ofSize: 17, weight: .medium)
        } else {
            font = UIFont.systemFont(ofSize: 17, weight: .medium)
        }
        
        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        barStyle = .black
        
        backIndicatorImage = UIImage(named: "back")
        backIndicatorTransitionMaskImage = UIImage(named: "back")
        
        titleTextAttributes = [
            .font: font,
        ]
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPress)))
        
        if #available(iOS 15.0, *) {
            // Fix odd grey navigation bar background when scrolled to top on iOS 15.
            scrollEdgeAppearance = standardAppearance
            
            //Set the status bar to use white text
            //TODO: We should compute this or save it in the theme plist, but currently there isn't a single theme where the statusbar shouldn't be white.
            overrideUserInterfaceStyle = .dark
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
