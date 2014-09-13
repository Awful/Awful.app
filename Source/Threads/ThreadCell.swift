//  ThreadCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class ThreadCell: UITableViewCell {
    @IBOutlet weak var tagImageView: UIImageView!
    @IBOutlet weak var secondaryTagImageView: UIImageView!
    
    // Strong references because we may remove them from their superview only to add them back later.
    @IBOutlet var ratingImageView: UIImageView!
    @IBOutlet var tagAndRatingContainerView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var unreadRepliesLabel: UILabel!
    @IBOutlet weak var numberOfPagesLabel: UILabel!
    @IBOutlet weak var killedByLabel: UILabel!
    @IBOutlet weak var stickyImageView: UIImageView!
    
    // MARK: Hide and show tag and/or rating
    
    /// Constraints needed when showing a rating image.
    @IBOutlet private var ratingConstraints: [NSLayoutConstraint]!
    
    /// Constraints needed when showing a tag image.
    @IBOutlet private var tagConstraints: [NSLayoutConstraint]!
    
    var showsRating: Bool = true {
        didSet(wasShowingRating) {
            if showsRating && !wasShowingRating {
                tagAndRatingContainerView.addSubview(ratingImageView)
                tagAndRatingContainerView.addConstraints(ratingConstraints)
            } else if !showsRating {
                ratingImageView.removeFromSuperview()
            }
        }
    }
    
    var showsTag: Bool = true {
        didSet(wasShowingTag) {
            if showsTag && !wasShowingTag {
                contentView.addSubview(tagAndRatingContainerView)
                contentView.addConstraints(tagConstraints)
            } else if !showsTag {
                tagAndRatingContainerView.removeFromSuperview()
            }
        }
    }
    
    // MARK: Long-press
    
    private var longPress: UILongPressGestureRecognizer!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        longPress = UILongPressGestureRecognizer(target: self, action: "didLongPress:")
        contentView.addGestureRecognizer(longPress)
    }
    
    private weak var longPressTarget: AnyObject!
    private var longPressAction: Selector!
    
    func setLongPressTarget(target: AnyObject!, action: String!) {
        if let action = action {
            longPress.enabled = true
            longPressTarget = target
            longPressAction = Selector(action)
        } else {
            longPress.enabled = false
            longPressTarget = nil
            longPressAction = nil
        }
    }
    
    @objc private func didLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .Began {
            UIApplication.sharedApplication().sendAction(longPressAction, to: longPressTarget, from: self, forEvent: nil)
        }
    }
    
    // MARK: Fonts
    
    var fontNameForLabels: String? {
        didSet {
            if fontNameForLabels != oldValue {
                let updateLabel = { (label: UILabel, textStyle: String) -> Void in
                    let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(textStyle)
                    let fontName = self.fontNameForLabels ?? descriptor.objectForKey(UIFontDescriptorNameAttribute) as String
                    label.font = UIFont(name: fontName, size: descriptor.pointSize)
                }
                
                // TODO remember to keep text styles in sync with nib. (This sucks; better way?)
                updateLabel(titleLabel, UIFontTextStyleBody)
                updateLabel(numberOfPagesLabel, UIFontTextStyleFootnote)
                updateLabel(killedByLabel, UIFontTextStyleFootnote)
                updateLabel(unreadRepliesLabel, UIFontTextStyleSubheadline)
            }
        }
    }
}
