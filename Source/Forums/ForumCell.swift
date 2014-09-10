//  ForumCell.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class ForumCell: UITableViewCell {
	
	@IBOutlet weak var nameLabel: UILabel!
}


class ForumListCell: ForumCell {

    @IBOutlet weak var disclosureButton: UIButton!
    @IBOutlet weak var nameSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var favoriteButton: UIButton!

    var subforumDepth: Int = 0 {
        didSet {
            nameSpaceConstraint.constant = 8 + CGFloat(subforumDepth) * 15
        }
    }
}
