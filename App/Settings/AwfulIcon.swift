//
//  AwfulIcon.swift
//  Awful
//
//  Created by Liam Westby on 9/24/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class AwfulIcon: UICollectionViewCell {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    var iconName: String = "" {
        didSet {
            imageView.image = UIImage(named: "AppIcon-\(iconName)-60x60", in: Bundle(for: type(of: self)), compatibleWith: nil)
            imageView.layer.cornerRadius = 10.0
            imageView.clipsToBounds = true
            if isCurrentIcon() {
                imageView.layer.borderWidth = 6
                imageView.layer.borderColor = (Theme.currentTheme["tintColor"]! as UIColor).cgColor
            } else {
                imageView.layer.borderWidth = 0
            }
        }
    }
    
    func isCurrentIcon() -> Bool {
        if #available(iOS 10.3, *) {
            return UIApplication.shared.alternateIconName ?? "Bars" == iconName
        }
        
        // Always get the bars if the version is too old
        return iconName == "Bars"
        
    }
}
