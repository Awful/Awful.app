//  SecondaryThreadTagPickerCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A secondary thread tag (like Ask in Ask/Tell) in a ThreadTagPickerViewController.
final class SecondaryThreadTagPickerCell: UICollectionViewCell {
    
    /// The image name of the secondary tag. The cell will draw its own rendition of the tag based on the image name.
    var tagImageName: String? {
        didSet {
            guard let name = tagImageName, let info = tagInfo[name] else { return }
            titleText = info["title"] ?? "?????"
            if let hexColor = info["color"], let color = UIColor(hex: hexColor) {
                drawColor = color
            } else {
                drawColor = UIColor.red
            }
        }
    }
    
    /// The color of the description that appears below the tag.
    var titleTextColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }
    
    private var titleText: String = "" {
        didSet { setNeedsDisplay() }
    }
    
    private var drawColor: UIColor = .red {
        didSet { setNeedsDisplay() }
    }
    
    override var isSelected: Bool {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: titleTextColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: -2, weight: .regular)]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleOrigin = CGPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - titleSize.height)
        let titleFrame = CGRect(origin: titleOrigin, size: titleSize)
        titleText.draw(in: titleFrame, withAttributes: titleAttributes)
        
        let diameter = titleFrame.minY
        let circleFrame = CGRect(x: bounds.midX - diameter / 2, y: 0, width: diameter, height: diameter)
            .insetBy(dx: 5, dy: 5)
        context.setFillColor(drawColor.cgColor)
        context.setStrokeColor(drawColor.cgColor)
        context.setLineWidth(1)
        isSelected ? context.fillEllipse(in: circleFrame) : context.strokeEllipse(in: circleFrame)
        
        let firstLetter = String(titleText.first ?? "?")
        let letterAttributes = [
            NSAttributedString.Key.foregroundColor: isSelected ? UIColor.white : drawColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 4, weight: .regular)]
        let letterSize = firstLetter.size(withAttributes: letterAttributes)
        let letterOrigin = CGPoint(
            x: circleFrame.midX - letterSize.width / 2,
            y: circleFrame.midY - letterSize.height / 2)
        firstLetter.draw(in: CGRect(origin: letterOrigin, size: letterSize), withAttributes: letterAttributes)
    }
}

private let tagInfo: [String: [String: String]] = {
    let bundle = Bundle(for: SecondaryThreadTagPickerCell.self)
    guard let url = bundle.url(forResource: "SecondaryTags", withExtension: "plist") else {
        fatalError("missing SecondaryTags.plist")
    }
    guard let dict = NSDictionary(contentsOf: url) as? [String: [String: String]] else {
        fatalError("unexpected format for SecondaryTags.plist")
    }
    return dict
}()
