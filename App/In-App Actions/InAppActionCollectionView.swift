//  InAppActionCollectionView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class InAppActionCollectionView: UICollectionView {

    override var intrinsicContentSize : CGSize {
        let contentSize = collectionViewLayout.collectionViewContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
    
}
