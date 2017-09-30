//
//  AppIconCell.swift
//  Awful
//
//  Created by Liam Westby on 9/24/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

final class AppIconCell: UICollectionViewCell {
    @IBOutlet private weak var imageView: UIImageView!

    func configure(image: UIImage?, isCurrentlySelectedIcon: Bool) {
        imageView.image = image

        if isCurrentlySelectedIcon {
            imageView.layer.borderWidth = 6
            imageView.layer.borderColor = (Theme.currentTheme["tintColor"]! as UIColor).cgColor
        } else {
            imageView.layer.borderWidth = 0
        }
    }
}
