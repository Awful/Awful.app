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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Can't put this in a nib used by UITableView ("must have exactly one top-level object hurf durf").
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(ThreadCell.didLongPress(_:)))
        contentView.addGestureRecognizer(longPress)
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: contentView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 75))
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: pageIcon, attribute: .bottom, relatedBy: .equal, toItem: numberOfPagesLabel, attribute: .lastBaseline, multiplier: 1, constant: 0))
        
        // UITableViewCell will have a left layout margin of 16 while the contentView will have a left layout margin of 8. This is not helpful.
        contentView.layoutMargins.left = 16
    }
    
    override func fontPointSizeForLabel(_ label: UILabel, suggestedPointSize: CGFloat) -> CGFloat {
        if label == unreadRepliesLabel {
            return suggestedPointSize + 2
        } else {
            return suggestedPointSize
        }
    }
    
    // MARK: Hide and show tag and/or rating
    
    /// Constraints needed when showing a rating image.
    @IBOutlet fileprivate var ratingConstraints: [NSLayoutConstraint]!
    
    /// Constraints needed when showing a tag image.
    @IBOutlet fileprivate var tagConstraints: [NSLayoutConstraint]!
    
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
    
    fileprivate(set) weak var longPressTarget: AnyObject!
    fileprivate(set) var longPressAction: Selector!
    
    func setLongPressTarget(_ target: AnyObject!, action: String!) {
        if let action = action {
            longPress.isEnabled = true
            longPressTarget = target
            longPressAction = Selector(action)
        } else {
            longPress.isEnabled = false
            longPressTarget = nil
            longPressAction = nil
        }
    }
    
    fileprivate var longPress: UILongPressGestureRecognizer!
    
    @objc fileprivate func didLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            UIApplication.shared.sendAction(longPressAction, to: longPressTarget, from: self, for: nil)
        }
    }
}

@IBDesignable
class TopCapAlignmentLabel: UILabel {
    
    override var alignmentRectInsets : UIEdgeInsets {
        var insets = super.alignmentRectInsets
        insets.top = ceil(font.ascender - font.capHeight)
        return insets
    }
}

import AVFoundation

@IBDesignable
class PageIcon: UIView {
    
    @IBInspectable var borderColor: UIColor = .darkGray {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        
        // Page shape.
        let outline = AVMakeRect(aspectRatio: CGSize(width: 8.5, height: 11), insideRect: bounds)
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
