//  ThemeButton.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Represents a selectable theme.
final class ThemeButton: UIButton {
    private let themeColor: UIColor
    
    init(themeColor: UIColor) {
        self.themeColor = themeColor
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func intrinsicContentSize() -> CGSize {
        return CGSize(width: 32, height: 32)
    }
    
    override func drawRect(rect: CGRect) {
        let borderWidth: CGFloat = 2
        let path = UIBezierPath(ovalInRect: bounds.insetBy(dx: borderWidth, dy: borderWidth))
        path.lineWidth = borderWidth
        themeColor.set()
        path.fill()
        
        if selected {
            tintColor.set()
            path.stroke()
        }
    }
}
