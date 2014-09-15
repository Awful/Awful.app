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
    @IBOutlet weak var killedByLabel: UILabel!
    @IBOutlet weak var stickyImageView: UIImageView!
    
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
        
        // UITableViewCell will have a left layout margin of 16 while the contentView will have a left layout margin of 8. This is not helpful.
        contentView.layoutMargins.left = 16
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
