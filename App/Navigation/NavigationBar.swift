//  NavigationBar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Long-tapping the back button of an AwfulNavigationBar will pop its navigation controller to its root view controller.
final class NavigationBar: UINavigationBar {
    private var observers: [NSKeyValueObservation] = []
    private let bottomBorder: CALayer = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // For whatever reason, translucent navbars with a barTintColor do not necessarily blur their backgrounds. An iPad 3, for example, blurs a bar without a barTintColor but is simply semitransparent with a barTintColor. The semitransparent, non-blur effect looks awful, so just turn it off.
        isTranslucent = false
        
        // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
        barStyle = .black
        
        backIndicatorImage = UIImage(named: "back")
        backIndicatorTransitionMaskImage = UIImage(named: "back")
        
        titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .regular)]
        
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(didLongPress)))
        
        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.isAlternateThemeEnabled, \.isDarkModeEnabled) {
                [unowned self] defaults in
                self.configureNavigationBarColor()
            }
        }
        
        configureNavigationBarColor()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        configureNavigationBarColor()
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
    
    private func configureNavigationBarColor() {
        print("NavigationBar configureNavigationBarColor entry")
        if UserDefaults.standard.isAlternateThemeEnabled && UserDefaults.standard.isDarkModeEnabled {
            print("adding border")
            bottomBorder.frame = CGRect(x: 0, y: frame.size.height - 0.5, width: frame.size.width, height: 0.5)
            bottomBorder.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
            bottomBorder.removeFromSuperlayer()
            layer.addSublayer(bottomBorder)
            layer.shadowOpacity = 0
        } else {
            print("removing border")
            bottomBorder.removeFromSuperlayer()
            layer.shadowOpacity = 1
        }
        
    }
}
