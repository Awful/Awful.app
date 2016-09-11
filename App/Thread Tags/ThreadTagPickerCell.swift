//  ThreadTagPickerCell.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A thread tag in an AwfulThreadTagPickerController.
final class ThreadTagPickerCell: UICollectionViewCell {
    fileprivate let tagView = ThreadTagView()
    fileprivate let imageNameLabel = UILabel()
    fileprivate let selectedIcon = UIImageView()
    
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
    
    override var isSelected: Bool {
        didSet { selectedIcon.isHidden = !isSelected }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageNameLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageNameLabel.numberOfLines = 0
        imageNameLabel.lineBreakMode = .byCharWrapping
        contentView.addSubview(imageNameLabel)
        
        tagView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(tagView)
        
        selectedIcon.image = UIImage(named: "selected-tick-icon")
        selectedIcon.isHidden = true
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
            guard let name = tagImageName, let info = tagInfo[name] else { return }
            titleText = info["title"] ?? "?????"
            if let hexColor = info["color"], let color = UIColor.fromHex(hexColor) {
                drawColor = color
            } else {
                drawColor = UIColor.red
            }
        }
    }
    
    /// The color of the description that appears below the tag.
    var titleTextColor: UIColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }
    
    fileprivate var titleText: String = "" {
        didSet { setNeedsDisplay() }
    }
    
    fileprivate var drawColor: UIColor = UIColor.red {
        didSet { setNeedsDisplay() }
    }
    
    override var isSelected: Bool {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let titleAttributes = [
            NSForegroundColorAttributeName: titleTextColor,
            NSFontAttributeName: UIFont.systemFont(ofSize: 12)] as [String : Any]
        let titleSize = titleText.size(attributes: titleAttributes)
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
        
        let firstLetter = String(titleText.characters.first ?? "?")
        let letterAttributes = [
            NSForegroundColorAttributeName: isSelected ? UIColor.white : drawColor,
            NSFontAttributeName: UIFont.systemFont(ofSize: 24)]
        let letterSize = firstLetter.size(attributes: letterAttributes)
        let letterOrigin = CGPoint(
            x: circleFrame.midX - letterSize.width / 2,
            y: circleFrame.midY - letterSize.height / 2)
        firstLetter.draw(in: CGRect(origin: letterOrigin, size: letterSize), withAttributes: letterAttributes)
    }
}

private let tagInfo: [String: [String: String]] = {
    guard let URL = Bundle(for: SecondaryTagPickerCell.self).url(forResource: "SecondaryTags.plist", withExtension: nil) else {
        fatalError("missing SecondaryTags.plist")
    }
    guard let dict = NSDictionary(contentsOf: URL) as? [String: [String: String]] else { fatalError("unexpected format for SecondaryTags.plist") }
    return dict
}()
