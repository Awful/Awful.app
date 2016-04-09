//  ThreadTagPickerLayout.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Horizontally centers the first section when there are multiple sections.
final class ThreadTagPickerLayout: UICollectionViewFlowLayout {
    private var pickerHasSecondaryTags: Bool {
        return collectionView?.numberOfSections() > 1
    }
    
    private var _centeringOffset: CGFloat = 0
    private var centeringOffset: CGFloat {
        get {
            guard _centeringOffset == 0 && pickerHasSecondaryTags else { return _centeringOffset }
            guard let
                collectionView = collectionView,
                firstAttributes = super.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0)),
                lastAttributes = super.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: collectionView.numberOfItemsInSection(0) - 1, inSection: 0))
                else { return _centeringOffset }
            let sectionWidth = firstAttributes.frame.union(lastAttributes.frame).width
            _centeringOffset = (collectionViewContentSize().width - sectionWidth) / 2
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
    
    override func invalidateLayoutWithContext(context: UICollectionViewLayoutInvalidationContext) {
        centeringOffset = 0
        super.invalidateLayoutWithContext(context)
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItemAtIndexPath(indexPath) else { return nil }
        guard indexPath.section == 0 && pickerHasSecondaryTags else { return attributes }
        let mutableAttributes = attributes.copy() as! UICollectionViewLayoutAttributes
        mutableAttributes.frame = attributes.frame.offsetBy(dx: centeringOffset, dy: 0)
        return mutableAttributes
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributeses = super.layoutAttributesForElementsInRect(rect) else { return nil }
        guard pickerHasSecondaryTags else { return attributeses }
        return attributeses.map { a in
            guard a.indexPath.section == 0 else { return a }
            let mutable = a.copy() as! UICollectionViewLayoutAttributes
            mutable.frame = a.frame.offsetBy(dx: centeringOffset, dy: 0)
            return mutable
        }
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        guard pickerHasSecondaryTags else { return super.shouldInvalidateLayoutForBoundsChange(newBounds) }
        return collectionView?.bounds.width != newBounds.width
    }
}
