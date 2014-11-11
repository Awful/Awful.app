//  ForumCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class ForumCell: DynamicTypeTableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var separator: UIView!
    
    class func minimumHeight() -> CGFloat {
        return 44
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: ForumCell.minimumHeight()))
        
        // Can't do this in IB.
        addConstraint(NSLayoutConstraint(item: separator, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1, constant: 0))
    }
}

class ForumTreeCell: ForumCell {
    
    @IBOutlet weak var disclosureButton: UIButton!
    @IBOutlet private weak var nameSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var favoriteButton: UIButton!

    var subforumDepth: Int = 0 {
        didSet {
            nameSpaceConstraint.constant = 8 + CGFloat(subforumDepth) * 15
        }
    }
}

class ForumFavoriteCell: ForumCell {
    
    @IBOutlet weak var starImageView: UIImageView!
    @IBOutlet weak var hiddenStarConstraint: NSLayoutConstraint!
    
    override func willTransitionToState(state: UITableViewCellStateMask) {
        super.willTransitionToState(state)
        if state & .ShowingEditControlMask != nil {
            starImageView.alpha = 0
            contentView.addConstraint(hiddenStarConstraint)
        } else {
            starImageView.alpha = 1
            contentView.removeConstraint(hiddenStarConstraint)
        }
    }
}
