//  ThreadTagPickerCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A thread tag in an AwfulThreadTagPickerController.
final class ThreadTagPickerCell: UICollectionViewCell {
    private let tagView = ThreadTagView()
    private let imageNameLabel = UILabel()
    private let selectedIcon = UIImageView()
    
    /// An image representing the thread tag.
    var image: UIImage? {
        get { return tagView.tagImage }
        set { tagView.tagImage = newValue }
    }
    
    /// Displayed as text in lieu of an image.
    var tagImageName: String? {
        get { return imageNameLabel.text }
        set { imageNameLabel.text = newValue }
    }
    
    override var selected: Bool {
        didSet { selectedIcon.hidden = !selected }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageNameLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        imageNameLabel.numberOfLines = 0
        imageNameLabel.lineBreakMode = .ByCharWrapping
        contentView.addSubview(imageNameLabel)
        
        tagView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        contentView.addSubview(tagView)
        
        selectedIcon.image = UIImage(named: "selected-tick-icon")
        selectedIcon.hidden = true
        contentView.addSubview(selectedIcon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        imageNameLabel.frame = CGRect(origin: .zero, size: bounds.size)
        tagView.frame = CGRect(origin: .zero, size: bounds.size)
        
        let selectedIconWidth: CGFloat = 31
        selectedIcon.frame = CGRect(
            x: bounds.maxX - selectedIconWidth,
            y: bounds.maxY - selectedIconWidth,
            width: selectedIconWidth,
            height: selectedIconWidth)
    }
}

/// A secondary thread tag (like Ask in Ask/Tell) in an AwfulThreadTagPickerController.
final class SecondaryTagPickerCell: UICollectionViewCell {
    /// The image name of the secondary tag. The cell will draw its own rendition of the tag based on the image name.
    var tagImageName: String? {
        didSet {
            guard let name = tagImageName, info = tagInfo[name] else { return }
            titleText = info["title"] ?? "?????"
            if let hexColor = info["color"] {
                drawColor = UIColor.awful_colorWithHexCode(hexColor)
            } else {
                drawColor = .redColor()
            }
        }
    }
    
    /// The color of the description that appears below the tag.
    var titleTextColor: UIColor = .whiteColor() {
        didSet { setNeedsDisplay() }
    }
    
    private var titleText: String = "" {
        didSet { setNeedsDisplay() }
    }
    
    private var drawColor: UIColor = .redColor() {
        didSet { setNeedsDisplay() }
    }
    
    override var selected: Bool {
        didSet { setNeedsDisplay() }
    }
    
    override func drawRect(rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let titleAttributes = [
            NSForegroundColorAttributeName: titleTextColor,
            NSFontAttributeName: UIFont.systemFontOfSize(12)]
        let titleSize = titleText.sizeWithAttributes(titleAttributes)
        let titleOrigin = CGPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.height - titleSize.height)
        let titleFrame = CGRect(origin: titleOrigin, size: titleSize)
        titleText.drawInRect(titleFrame, withAttributes: titleAttributes)
        
        let diameter = titleFrame.minY
        let circleFrame = CGRect(x: bounds.midX - diameter / 2, y: 0, width: diameter, height: diameter)
            .insetBy(dx: 5, dy: 5)
        context.setFillColor(drawColor.CGColor)
        context.setStrokeColor(drawColor.CGColor)
        context.setLineWidth(1)
        selected ? context.fillEllipse(inRect: circleFrame) : context.strokeEllipse(inRect: circleFrame)
        
        let firstLetter = String(titleText.characters.first ?? "?")
        let letterAttributes = [
            NSForegroundColorAttributeName: selected ? UIColor.whiteColor() : drawColor,
            NSFontAttributeName: UIFont.systemFontOfSize(24)]
        let letterSize = firstLetter.sizeWithAttributes(letterAttributes)
        let letterOrigin = CGPoint(
            x: circleFrame.midX - letterSize.width / 2,
            y: circleFrame.midY - letterSize.height / 2)
        firstLetter.drawInRect(CGRect(origin: letterOrigin, size: letterSize), withAttributes: letterAttributes)
    }
}

private let tagInfo: [String: [String: String]] = {
    guard let URL = NSBundle(forClass: SecondaryTagPickerCell.self).URLForResource("SecondaryTags.plist", withExtension: nil) else {
        fatalError("missing SecondaryTags.plist")
    }
    guard let dict = NSDictionary(contentsOfURL: URL) as? [String: [String: String]] else { fatalError("unexpected format for SecondaryTags.plist") }
    return dict
}()
