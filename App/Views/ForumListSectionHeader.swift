//  ForumListSectionHeader.swift
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ForumListSectionHeader: UITableViewHeaderFooterView {
    let sectionNameLabel: UILabel = UILabel()
    var leftInset: CGFloat = 40 {
        didSet { setNeedsLayout() }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(sectionNameLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let insets = UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: 0)
        sectionNameLabel.frame = UIEdgeInsetsInsetRect(CGRect(origin: .zero, size: bounds.size), insets)
    }
}
