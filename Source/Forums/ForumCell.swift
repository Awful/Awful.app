//  ForumCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class ForumCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet private weak var separatorHeightConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Can't do this in IB.
        contentView.addConstraint(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 44))
        
        // Can't do this in IB.
        separatorHeightConstraint.constant = 0.5
    }
}

class ForumListCell: ForumCell {
    @IBOutlet weak var disclosureButton: UIButton!
    @IBOutlet private weak var nameSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var favoriteButton: UIButton!

    var subforumDepth: Int = 0 {
        didSet {
            nameSpaceConstraint.constant = 8 + CGFloat(subforumDepth) * 15
        }
    }
}
