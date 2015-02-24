//  InAppActionCollectionViewLayout.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class InAppActionCollectionViewLayout: UICollectionViewLayout {
    
    var itemSize: CGSize = CGSize(width: 70, height: 90) {
        didSet { invalidateLayout() }
    }
    var interitemSpacing: CGFloat = 6 {
        didSet { invalidateLayout() }
    }
    var lineSpacing: CGFloat = 5 {
        didSet { invalidateLayout() }
    }
    
    private var allAttributes = [UICollectionViewLayoutAttributes]()
    
    private var contentSize: CGSize = CGSizeZero {
        didSet(oldSize) {
            if oldSize.height != contentSize.height {
                collectionView?.invalidateIntrinsicContentSize()
            }
        }
    }
    
    override func prepareLayout() {
        assert(collectionView!.numberOfSections() <= 1, "InAppActionLayout only works with one section")
        allAttributes.removeAll()
        
        /*
        We want the following layouts:
        
                +---------+            +---------+            +---------+
        1 item  |    X    |    2 items |   X  X  |    3 items | X  X  X |
                +---------+            +---------+            +---------+
        
                +---------+            +---------+            +---------+
        4 items | X  X  X |    5 items | X  X  X |    6 items | X  X  X |
                | X       |            | X  X    |            | X  X  X |
                +---------+            +---------+            +---------+
        
                +---------+            +---------+            +---------+
        7 items |X  X  X  |X   8 items |X  X  X  |X   9 items |X  X  X  |X  X
                |X  X  X  |            |X  X  X  |X           |X  X  X  |X
                +---------+            +---------+            +---------+
        */
        
        func widthForItems(numberOfItems: Int) -> CGFloat {
            assert(numberOfItems > 0)
            return CGFloat(numberOfItems) * itemSize.width + (CGFloat(numberOfItems) - 1) * interitemSpacing
        }
        func appendAttributesWithFrame(frame: CGRect) {
            let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: NSIndexPath(forItem: allAttributes.count, inSection: 0))
            attributes.frame = frame
            allAttributes.append(attributes)
        }
        let itemCount = collectionView!.numberOfItemsInSection(0)
        let bounds = collectionView!.bounds
        
        if widthForItems(itemCount) <= bounds.width {
            // The top row of the diagram
            let width = widthForItems(itemCount)
            let margin = (bounds.width - width) / 2
            var frame = CGRect(x: margin, y: 0, width: itemSize.width, height: itemSize.height)
            for _ in 0..<itemCount {
                appendAttributesWithFrame(frame)
                frame.origin.x += frame.width + interitemSpacing
            }
            
        } else if widthForItems(itemCount / 2 + itemCount % 2) <= bounds.width {
            // The middle row of the diagram
            var frame = CGRect(origin: CGPointZero, size: itemSize)
            for _ in 0..<itemCount {
                appendAttributesWithFrame(frame)
                frame.origin.x += frame.width + interitemSpacing
                if CGRectGetMaxX(frame) > bounds.width {
                    frame.origin.x = 0
                    frame.origin.y += frame.height + lineSpacing
                }
            }
            
            let margin = (bounds.width - maxElement(map(allAttributes, { CGRectGetMaxX($0.frame) }))) / 2
            for attributes in allAttributes {
                attributes.center.x += margin
            }
            
        } else {
            // The bottom row of the diagram
            var frame = CGRect(origin: CGPointZero, size: itemSize)
            let halfway = itemCount / 2 + itemCount % 2
            for _ in 0..<halfway {
                appendAttributesWithFrame(frame)
                frame.origin.x += frame.width + interitemSpacing
            }
            frame.origin.x = 0
            frame.origin.y += frame.height + lineSpacing
            for _ in halfway..<itemCount {
                appendAttributesWithFrame(frame)
                frame.origin.x += frame.width + interitemSpacing
            }
        }
        
        contentSize = CGSize(
            width: max(maxElement(map(allAttributes, { CGRectGetMaxX($0.frame) })), bounds.width),
            height: maxElement(map(allAttributes, { CGRectGetMaxY($0.frame) }))
        )
    }
    
    override func collectionViewContentSize() -> CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        return allAttributes.filter { CGRectIntersectsRect(rect, $0.frame) }
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return allAttributes[indexPath.item]
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return newBounds.width != collectionView!.bounds.width
    }
    
}
