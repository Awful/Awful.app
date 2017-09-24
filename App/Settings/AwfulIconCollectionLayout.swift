//
//  IconCollectionViewLayout.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class AwfulIconCollectionLayout: UICollectionViewFlowLayout {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.scrollDirection = .horizontal
        self.minimumInteritemSpacing = 10
        self.estimatedItemSize = CGSize(width: 70, height: 120)
        self.sectionInset = UIEdgeInsetsMake(0, 10, 0, 10)
    }
}
