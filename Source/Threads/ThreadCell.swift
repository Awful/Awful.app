//  ThreadCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class ThreadCell: DynamicTypeTableViewCell {
    @IBOutlet weak var tagImageView: UIImageView!
    @IBOutlet weak var secondaryTagImageView: UIImageView!
    
    // Strong references because we may remove them from their superview only to add them back later.
    @IBOutlet var ratingImageView: UIImageView!
    @IBOutlet var tagAndRatingContainerView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var unreadRepliesLabel: UILabel!
    @IBOutlet weak var numberOfPagesLabel: UILabel!
    @IBOutlet weak var pageIcon: PageIcon!
    @IBOutlet weak var killedByLabel: UILabel!
    @IBOutlet weak var stickyImageView: UIImageView!
    
    @IBOutlet weak var separator: UIView!
    @IBOutlet private weak var separatorHeightConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Can't put this in a nib used by UITableView ("must have exactly one top-level object hurf durf").
        longPress = UILongPressGestureRecognizer(target: self, action: "didLongPress:")
        contentView.addGestureRecognizer(longPress)
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 75))
        
        // Can't do this in IB.
        separatorHeightConstraint.constant = 0.5
        
        // Can't do this in IB.
        addConstraint(NSLayoutConstraint(item: separator, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1, constant: 0))
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: pageIcon, attribute: .Bottom, relatedBy: .Equal, toItem: numberOfPagesLabel, attribute: .Baseline, multiplier: 1, constant: 0))
        
        // UITableViewCell will have a left layout margin of 16 while the contentView will have a left layout margin of 8. This is not helpful.
        contentView.layoutMargins.left = 16
    }
    
    override func fontPointSizeForLabel(label: UILabel, suggestedPointSize: CGFloat) -> CGFloat {
        if label == unreadRepliesLabel {
            return suggestedPointSize + 2
        } else {
            return suggestedPointSize
        }
    }
    
    
    
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
    
    private(set) weak var longPressTarget: AnyObject!
    private(set) var longPressAction: Selector!
    
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
    
    private var longPress: UILongPressGestureRecognizer!
    
    @objc private func didLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .Began {
            UIApplication.sharedApplication().sendAction(longPressAction, to: longPressTarget, from: self, forEvent: nil)
        }
    }
}

@IBDesignable
class TopCapAlignmentLabel: UILabel {
    override func alignmentRectInsets() -> UIEdgeInsets {
        var insets = super.alignmentRectInsets()
        insets.top = ceil(font.ascender - font.capHeight)
        return insets
    }
}

import AVFoundation

@IBDesignable
class PageIcon: UIView {
    @IBInspectable var borderColor: UIColor = UIColor.darkGrayColor() {
        didSet { setNeedsDisplay() }
    }
    
    override func drawRect(rect: CGRect) {
        
        // Page shape.
        let outline = AVMakeRectWithAspectRatioInsideRect(CGSize(width: 8.5, height: 11), bounds)
        let borderPath = UIBezierPath()
        borderPath.moveToPoint(CGPoint(x: CGRectGetMinX(outline), y: CGRectGetMinY(outline)))
        borderPath.addLineToPoint(CGPoint(x: CGRectGetMinX(outline) + outline.width * 5/8, y: CGRectGetMinY(outline)))
        borderPath.addLineToPoint(CGPoint(x: CGRectGetMaxX(outline), y: CGRectGetMinY(outline) + ceil(outline.height / 3)))
        borderPath.addLineToPoint(CGPoint(x: CGRectGetMaxX(outline), y: CGRectGetMaxY(outline)))
        borderPath.addLineToPoint(CGPoint(x: CGRectGetMinX(outline), y: CGRectGetMaxY(outline)))
        borderPath.closePath()
        borderPath.lineWidth = 1
        
        // Dog-eared corner.
        let dogEar = UIBezierPath(rect: CGRect(x: CGRectGetMidX(outline), y: CGRectGetMinY(outline), width: CGRectGetWidth(outline) / 2, height: CGRectGetHeight(outline) / 2))
        
        borderPath.addClip()
        borderColor.set()
        borderPath.stroke()
        dogEar.fill()
    }
}
