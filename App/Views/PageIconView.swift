//  PageIconView.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AVFoundation
import UIKit

@IBDesignable
final class PageIconView: UIView {

    @IBInspectable var borderColor: UIColor = .darkGray {
        didSet { setNeedsDisplay() }
    }

    static let aspectRatio: CGFloat = 7 / 9

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ rect: CGRect) {

        // Page shape.
        let outline = AVMakeRect(aspectRatio: CGSize(width: 7, height: 9), insideRect: bounds)
        let borderPath = UIBezierPath()
        borderPath.move(to: CGPoint(x: outline.minX, y: outline.minY))
        borderPath.addLine(to: CGPoint(x: outline.minX + outline.width * 5/8, y: outline.minY))
        borderPath.addLine(to: CGPoint(x: outline.maxX, y: outline.minY + ceil(outline.height / 3)))
        borderPath.addLine(to: CGPoint(x: outline.maxX, y: outline.maxY))
        borderPath.addLine(to: CGPoint(x: outline.minX, y: outline.maxY))
        borderPath.close()
        borderPath.lineWidth = 1

        // Dog-eared corner.
        let dogEar = UIBezierPath(rect: CGRect(x: outline.midX, y: outline.minY, width: outline.width / 2, height: outline.height / 2))

        borderPath.addClip()
        borderColor.set()
        borderPath.stroke()
        dogEar.fill()
    }
}
