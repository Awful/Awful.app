//  Toolbar.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets its default tint color.
final class Toolbar: UIToolbar {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tintColor = UIColor(red: 0.078, green: 0.514, blue: 0.694, alpha: 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
