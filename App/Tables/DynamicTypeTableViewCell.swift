//  DynamicTypeTableViewCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
A table view cell that updates its Dynamic Type labels whenever the preferred size changes.

A maximum point size (the largest available setting before augmenting with accessibility) is enforced.
*/
class DynamicTypeTableViewCell: UITableViewCell {
    /// Labels that should update whenever Dynamic Type settings change.
    @IBOutlet fileprivate var dynamicTypeLabels: [UILabel]!
    
    fileprivate var observer: NSObjectProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
    
        if let identifier = reuseIdentifier {
            if guessedTextStylesByIdentifier[identifier] == nil {
                let guesses = dynamicTypeLabels.map { label in guessTextStyle(label) }
                guessedTextStylesByIdentifier[identifier] = guesses
            }
        }
        
        updateFonts()
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil, queue: OperationQueue.main) { notification in
            self.updateFonts()
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    fileprivate func updateFonts() {
        let maximumSizes: [String:CGFloat] = [
            UIFontTextStyle.headline.rawValue: 23,
            UIFontTextStyle.subheadline.rawValue: 12,
            UIFontTextStyle.body.rawValue: 23,
            UIFontTextStyle.caption1.rawValue: 18,
            UIFontTextStyle.caption2.rawValue: 17,
            UIFontTextStyle.footnote.rawValue: 19,
        ]
        eachLabelWithTextStyle { label, textStyle in
            let maximum = maximumSizes[textStyle] ?? 0
            var descriptor = fontDescriptorForTextStyle(textStyle, maximumPointSize: maximum)
            descriptor = descriptor.withSize(self.fontPointSizeForLabel(label, suggestedPointSize: descriptor.pointSize))
            if let customFontName = self.fontNameForLabels {
                label.font = UIFont(name: customFontName, size: descriptor.pointSize)
            } else {
                label.font = UIFont(descriptor: descriptor, size: 0)
            }
        }
    }
    
    func fontPointSizeForLabel(_ label: UILabel, suggestedPointSize: CGFloat) -> CGFloat {
        return suggestedPointSize
    }
    
    fileprivate func eachLabelWithTextStyle(_ block: (UILabel, String) -> Void) {
        let guessedTextStyles = guessedTextStylesByIdentifier[reuseIdentifier!]!
        for (label, textStyle) in zip(dynamicTypeLabels, guessedTextStyles) {
            if let textStyle = textStyle {
                block(label, textStyle)
            }
        }
    }
    
    /// Overrides the font name used for all Dynamic Type labels. The default is `nil`, which uses the default system font.
    var fontNameForLabels: String? {
        didSet {
            if fontNameForLabels != oldValue {
                updateFonts()
            }
        }
    }
}
    
private func guessTextStyle(_ label: UILabel) -> String? {
    let textStyles = [
        UIFontTextStyle.headline,
        UIFontTextStyle.subheadline,
        UIFontTextStyle.body,
        UIFontTextStyle.footnote,
        UIFontTextStyle.caption1,
        UIFontTextStyle.caption2,
    ]
    for textStyle in textStyles {
        if label.font == UIFont.preferredFont(forTextStyle: textStyle) {
            return textStyle.rawValue
        }
    }
    return nil
}

private var guessedTextStylesByIdentifier = [String:[String?]]()

private func fontDescriptorForTextStyle(_ textStyle: String, maximumPointSize: CGFloat) -> UIFontDescriptor {
    let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle(rawValue: textStyle))
    return descriptor.withSize(min(descriptor.pointSize, maximumPointSize))
}
