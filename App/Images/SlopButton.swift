//  SlopButton.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@IBDesignable
final class SlopButton: UIButton {
    @IBInspectable var horizontalSlop: CGFloat = 0
    @IBInspectable var verticalSlop: CGFloat = 0
    
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, withEvent: event) {
            return view
        }
        
        if bounds.rectByInsetting(dx: -horizontalSlop, dy: -verticalSlop).contains(point) {
            return self
        }
        
        return nil
    }
}
