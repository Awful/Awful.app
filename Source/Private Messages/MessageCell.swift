//  MessageCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class MessageCell: UITableViewCell {

    // Strong because they come and go from their superview.
    @IBOutlet var tagImageView: UIImageView!
    @IBOutlet var tagOverlayImageView: UIImageView!
    
    @IBOutlet weak var subjectLabel: UILabel!
    @IBOutlet weak var fromDateLabel: UILabel!
    
    // Constraints that get added or removed as the tag comes and goes.
    @IBOutlet var tagConstraints: [NSLayoutConstraint]!
    
    var showsTag: Bool = true {
        didSet {
            if showsTag {
                if tagImageView.superview == nil {
                    contentView.addSubview(tagImageView)
                    contentView.addSubview(tagOverlayImageView)
                    contentView.addConstraints(tagConstraints)
                }
            } else {
                tagImageView.removeFromSuperview()
                tagOverlayImageView.removeFromSuperview()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        separatorInset = UIEdgeInsets(top: 0, left: CGRectGetMinX(subjectLabel.frame), bottom: 0, right: 0)
    }
}
