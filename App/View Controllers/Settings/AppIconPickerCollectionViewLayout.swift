//  AppIconPickerCollectionViewLayout.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class AppIconPickerCollectionViewLayout: UICollectionViewFlowLayout {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.scrollDirection = .horizontal
        self.minimumInteritemSpacing = 10
        self.itemSize = CGSize(width: 60, height: 60)
        self.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
}
