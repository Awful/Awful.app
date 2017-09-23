//
//  IconCollectionViewLayout.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class IconCollectionViewLayout: UICollectionViewFlowLayout {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.scrollDirection = .horizontal
        self.minimumInteritemSpacing = 10
        self.itemSize = CGSize(width: 70, height: 120)
    }
    
    
}
