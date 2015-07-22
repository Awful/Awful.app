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
    @IBOutlet private var dynamicTypeLabels: [UILabel]!
    
    private var observer: NSObjectProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
    
        if let identifier = reuseIdentifier {
            if guessedTextStylesByIdentifier[identifier] == nil {
                let guesses = dynamicTypeLabels.map { label in guessTextStyle(label) }
                guessedTextStylesByIdentifier[identifier] = guesses
            }
        }
        
        updateFonts()
        observer = NSNotificationCenter.defaultCenter().addObserverForName(UIContentSizeCategoryDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
            self.updateFonts()
        }
    }
    
    deinit {
        if let observer = observer {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
    private func updateFonts() {
        let maximumSizes: [String:CGFloat] = [
            UIFontTextStyleHeadline: 23,
            UIFontTextStyleSubheadline: 12,
            UIFontTextStyleBody: 23,
            UIFontTextStyleCaption1: 18,
            UIFontTextStyleCaption2: 17,
            UIFontTextStyleFootnote: 19,
        ]
        eachLabelWithTextStyle { label, textStyle in
            let maximum = maximumSizes[textStyle] ?? 0
            var descriptor = fontDescriptorForTextStyle(textStyle, maximumPointSize: maximum)
            descriptor = descriptor.fontDescriptorWithSize(self.fontPointSizeForLabel(label, suggestedPointSize: descriptor.pointSize))
            if let customFontName = self.fontNameForLabels {
                label.font = UIFont(name: customFontName, size: descriptor.pointSize)
            } else {
                label.font = UIFont(descriptor: descriptor, size: 0)
            }
        }
    }
    
    func fontPointSizeForLabel(label: UILabel, suggestedPointSize: CGFloat) -> CGFloat {
        return suggestedPointSize
    }
    
    private func eachLabelWithTextStyle(block: (UILabel, String) -> Void) {
        let guessedTextStyles = guessedTextStylesByIdentifier[reuseIdentifier!]!
        for (label, textStyle) in Zip2Sequence(dynamicTypeLabels, guessedTextStyles) {
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
    
private func guessTextStyle(label: UILabel) -> String? {
    let textStyles = [
        UIFontTextStyleHeadline,
        UIFontTextStyleSubheadline,
        UIFontTextStyleBody,
        UIFontTextStyleFootnote,
        UIFontTextStyleCaption1,
        UIFontTextStyleCaption2,
    ]
    for textStyle in textStyles {
        if label.font == UIFont.preferredFontForTextStyle(textStyle) {
            return textStyle
        }
    }
    return nil
}

private var guessedTextStylesByIdentifier = [String:[String?]]()

private func fontDescriptorForTextStyle(textStyle: String, maximumPointSize: CGFloat) -> UIFontDescriptor {
    let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(textStyle)
    return descriptor.fontDescriptorWithSize(min(descriptor.pointSize, maximumPointSize))
}
