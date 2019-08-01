//  PrimarySidebarCell.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class PrimarySidebarCell: UITableViewCell {

    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!

    static let estimatedRowHeight: CGFloat = 44

    func configure(icon: UIImage?, title: String) {
        iconImageView.image = icon
        titleLabel.text = title
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        titleLabel.textColor = tintColor
    }
}
