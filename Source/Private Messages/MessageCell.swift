//  MessageCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class MessageCell: DynamicTypeTableViewCell {

    // Strong because it comes and goes from its superview.
    @IBOutlet var tagImageView: UIImageView!

    @IBOutlet weak var tagOverlayImageView: UIImageView!
    @IBOutlet weak var senderLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    
    @IBOutlet weak var separator: UIView!
    @IBOutlet private weak var separatorHeightConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 65))
        
        // Can't do this in IB.
        separatorHeightConstraint.constant = 0.5
        
        // Can't do this in IB.
        addConstraint(NSLayoutConstraint(item: separator, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1, constant: 0))
        
        // UITableViewCell will have a left layout margin of 16 while the contentView will have a left layout margin of 8. This is not helpful.
        contentView.layoutMargins.left = 22
    }
    
    // Constraints that get added or removed as the tag comes and goes.
    @IBOutlet private var tagConstraints: [NSLayoutConstraint]!
    
    var showsTag: Bool = true {
        didSet {
            if showsTag {
                if tagImageView.superview == nil {
                    contentView.insertSubview(tagImageView, belowSubview: tagOverlayImageView)
                    contentView.addConstraints(tagConstraints)
                }
            } else {
                tagImageView.removeFromSuperview()
            }
        }
    }
    
    // MARK: DynamicTypeTableViewCell
    
    override func fontPointSizeForLabel(label: UILabel, suggestedPointSize: CGFloat) -> CGFloat {
        switch (label) {
        case subjectLabel, dateLabel:
            return suggestedPointSize - 2
        default:
            return suggestedPointSize
        }
    }
}
