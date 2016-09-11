//  ThemeButton.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Represents a selectable theme.
final class ThemeButton: UIButton {
    fileprivate let themeColor: UIColor
    
    init(themeColor: UIColor) {
        self.themeColor = themeColor
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 32, height: 32)
    }
    
    override func draw(_ rect: CGRect) {
        let borderWidth: CGFloat = 2
        let path = UIBezierPath(ovalIn: bounds.insetBy(dx: borderWidth, dy: borderWidth))
        path.lineWidth = borderWidth
        themeColor.set()
        path.fill()
        
        if isSelected {
            tintColor.set()
            path.stroke()
        }
    }
}
