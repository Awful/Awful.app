//  PaginatedHorizontalCollectionViewLayout.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class PaginatedHorizontalCollectionViewLayout: UICollectionViewLayout {
    
    var delegate: PaginatedHorizontalLayoutDelegate {
        get { return collectionView!.delegate as PaginatedHorizontalLayoutDelegate }
    }
    
    var numberOfPages: Int = 0 {
        didSet { delegate.collectionView?(collectionView!, numberOfPagesDidChangeInLayout: self) }
    }
    
    var currentPage: Int { get {
        return Int(round(collectionView!.contentOffset.x / collectionView!.bounds.width)) }
    }
    
    var lineSpacing: CGFloat = 5 {
        didSet { invalidateLayout() }
    }
    
    var interitemSpacing: CGFloat = 5 {
        didSet { invalidateLayout() }
    }
    
    private var itemAttributes = [UICollectionViewLayoutAttributes]()
    
    override func prepareLayout() {
        itemAttributes.removeAll()
        
        let pageSize = collectionView!.bounds.size
        var page: CGFloat = 1
        let contentInset = collectionView!.contentInset
        var offset: CGPoint = CGPoint(x: contentInset.left, y: contentInset.top)
        var rowBottom: CGFloat = 0
        for i in 0 ..< collectionView!.dataSource!.collectionView(collectionView!, numberOfItemsInSection: 0) {
            let indexPath = NSIndexPath(forItem: i, inSection: 0)
            let cellSize = delegate.collectionView(collectionView!, layout: self, sizeForItemAtIndexPath: indexPath)
            
            if (offset.x + cellSize.width + contentInset.right) / pageSize.width > page {
                offset.x = (page - 1) * pageSize.width + contentInset.left
                offset.y += rowBottom + lineSpacing
                rowBottom = 0
            }
            if offset.y + cellSize.height + contentInset.bottom > pageSize.height {
                page += 1
                offset.x = (page - 1) * pageSize.width + contentInset.left
                offset.y = contentInset.top
                rowBottom = 0
            }
            
            let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
            attributes.frame = CGRect(origin: offset, size: cellSize)
            itemAttributes.append(attributes)
            
            offset.x += cellSize.width + interitemSpacing
            rowBottom = max(rowBottom, cellSize.height)
        }
        
        numberOfPages = Int(page)
    }
    
    override func collectionViewContentSize() -> CGSize {
        let lastFrame = itemAttributes.last!.frame
        let bounds = collectionView!.bounds
        return CGSize(width: CGRectGetMaxX(lastFrame) + (bounds.width - CGRectGetMaxX(lastFrame) % bounds.width), height: bounds.height)
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        return filter(itemAttributes) { CGRectIntersectsRect(rect, $0.frame) }
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return itemAttributes[indexPath.item]
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return collectionView!.bounds.size != newBounds.size
    }
    
}

@objc protocol PaginatedHorizontalLayoutDelegate: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, layout: PaginatedHorizontalCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    
    optional func collectionView(collectionView: UICollectionView, numberOfPagesDidChangeInLayout layout: PaginatedHorizontalCollectionViewLayout)
}
