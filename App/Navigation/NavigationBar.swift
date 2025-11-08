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
