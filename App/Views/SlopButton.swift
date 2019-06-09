//  SlopButton.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@IBDesignable
final class SlopButton: UIButton {
    @IBInspectable var horizontalSlop: CGFloat = 0
    @IBInspectable var verticalSlop: CGFloat = 0
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            return view
        }
        
        if bounds.insetBy(dx: -horizontalSlop, dy: -verticalSlop).contains(point) {
            return self
        }
        
        return nil
    }
}
