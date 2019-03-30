//  Toolbar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets its default tint color.
final class Toolbar: UIToolbar {
    private var observers: [NSKeyValueObservation] = []
    private let topBorder: CALayer = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tintColor = UIColor(red: 0.078, green: 0.514, blue: 0.694, alpha: 1)

        observers += UserDefaults.standard.observeSeveral {
            $0.observe(\.isAlternateThemeEnabled, \.isDarkModeEnabled) {
                [unowned self] defaults in
                self.configureToolbarColor()
            }
        }
        
        configureToolbarColor()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureToolbarColor() {
        if UserDefaults.standard.isAlternateThemeEnabled && UserDefaults.standard.isDarkModeEnabled {
            isTranslucent = false
            
            topBorder.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: 0.5)
            topBorder.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor
            
            layer.addSublayer(topBorder)
        } else {
            isTranslucent = true
            topBorder.removeFromSuperlayer()
        }
    }
}
