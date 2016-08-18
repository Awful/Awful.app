//  NavigationBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Long-tapping the back button of an AwfulNavigationBar will pop its navigation controller to its root view controller.
final class NavigationBar: UINavigationBar {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // For whatever reason, translucent navbars with a barTintColor do not necessarily blur their backgrounds. An iPad 3, for example, blurs a bar without a barTintColor but is simply semitransparent with a barTintColor. The semitransparent, non-blur effect looks awful, so just turn it off.
        translucent = false
        
        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        barStyle = .Black
        
        backIndicatorImage = UIImage(named: "back-padded")
        backIndicatorTransitionMaskImage = UIImage(named: "back-padded")
        
        titleTextAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(17, weight: UIFontWeightRegular)]
        
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPress)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func didLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .Began else { return }
        guard backItem != nil else { return }
        guard let nav = delegate as? UINavigationController else { return }
        
        // Try to find the back button's view without accessing its private `_view` ivar.
        guard let leftmost = subviews.lazy
            .filter({$0.bounds.width < self.bounds.width / 2})
            .minElement({$0.frame.minX < $1.frame.minX || $0.bounds.width > $1.bounds.width}),
            leftmost.bounds.contains(sender.locationInView(leftmost))
            else { return }
        nav.popToRootViewControllerAnimated(true)
    }
}
