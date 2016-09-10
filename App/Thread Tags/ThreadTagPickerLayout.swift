//  ThreadTagPickerLayout.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


/// Horizontally centers the first section when there are multiple sections.
final class ThreadTagPickerLayout: UICollectionViewFlowLayout {
    fileprivate var pickerHasSecondaryTags: Bool {
        return collectionView?.numberOfSections > 1
    }
    
    fileprivate var _centeringOffset: CGFloat = 0
    fileprivate var centeringOffset: CGFloat {
        get {
            guard _centeringOffset == 0 && pickerHasSecondaryTags else { return _centeringOffset }
            guard let
                collectionView = collectionView,
                let firstAttributes = super.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)),
                let lastAttributes = super.layoutAttributesForItem(at: IndexPath(item: collectionView.numberOfItems(inSection: 0) - 1, section: 0))
                else { return _centeringOffset }
            let sectionWidth = firstAttributes.frame.union(lastAttributes.frame).width
            _centeringOffset = (collectionViewContentSize.width - sectionWidth) / 2
            return _centeringOffset
        }
        set {
            _centeringOffset = newValue
        }
    }
    
    override func invalidateLayout() {
        centeringOffset = 0
        super.invalidateLayout()
    }
    
    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        centeringOffset = 0
        super.invalidateLayout(with: context)
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else { return nil }
        guard (indexPath as NSIndexPath).section == 0 && pickerHasSecondaryTags else { return attributes }
        let mutableAttributes = attributes.copy() as! UICollectionViewLayoutAttributes
        mutableAttributes.frame = attributes.frame.offsetBy(dx: centeringOffset, dy: 0)
        return mutableAttributes
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributeses = super.layoutAttributesForElements(in: rect) else { return nil }
        guard pickerHasSecondaryTags else { return attributeses }
        return attributeses.map { a in
            guard (a.indexPath as NSIndexPath).section == 0 else { return a }
            let mutable = a.copy() as! UICollectionViewLayoutAttributes
            mutable.frame = a.frame.offsetBy(dx: centeringOffset, dy: 0)
            return mutable
        }
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard pickerHasSecondaryTags else { return super.shouldInvalidateLayout(forBoundsChange: newBounds) }
        return collectionView?.bounds.width != newBounds.width
    }
}
