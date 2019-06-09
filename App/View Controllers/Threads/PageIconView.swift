//  PageIconView.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AVFoundation
import UIKit

@IBDesignable
final class PageIconView: UIView {

    @IBInspectable var borderColor: UIColor = UIColor(white: 0.552, alpha: 0.5) {
        didSet { setNeedsDisplay() }
    }

    static let aspectRatio: CGFloat = 21 / 27

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let outline = AVMakeRect(aspectRatio: CGSize(width: PageIconView.aspectRatio, height: 1), insideRect: bounds)
        context.translateBy(x: outline.minX, y: outline.minY)
        context.scaleBy(x: outline.width / 21, y: outline.height / 27)

        let path = UIBezierPath()
        path.lineWidth = 4

        path.move(to: CGPoint(x: 0.5, y: 0.5))
        path.addLine(to: CGPoint(x: 12, y: 0.5))
        path.addLine(to: CGPoint(x: 20.5, y: 9))
        path.addLine(to: CGPoint(x: 20.5, y: 26.5))
        path.addLine(to: CGPoint(x: 0.5, y: 26.5))
        path.close()

        borderColor.set()

        path.stroke()

        path.addClip()
        UIRectFill(CGRect(x: 11.5, y: 1, width: 9.5, height: 8.5))
    }
}
