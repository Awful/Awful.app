//  InAppActionCollectionViewLayout.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

class InAppActionCollectionViewLayout: UICollectionViewLayout {
    
    var itemSize: CGSize = CGSize(width: 70, height: 70) {
        didSet { invalidateLayout() }
    }
    var interitemSpacing: CGFloat = 6 {
        didSet { invalidateLayout() }
    }
    var lineSpacing: CGFloat = 5 {
        didSet { invalidateLayout() }
    }
    
    fileprivate var allAttributes = [UICollectionViewLayoutAttributes]()
    
    fileprivate var contentSize: CGSize = .zero {
        didSet(oldSize) {
            if oldSize.height != contentSize.height {
                collectionView?.invalidateIntrinsicContentSize()
            }
        }
    }
    
    override func prepare() {
        assert(collectionView!.numberOfSections <= 1, "InAppActionLayout only works with one section")
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
        
        func widthForItems(_ numberOfItems: Int) -> CGFloat {
            assert(numberOfItems > 0)
            return CGFloat(numberOfItems) * itemSize.width + (CGFloat(numberOfItems) - 1) * interitemSpacing
        }
        func appendAttributesWithFrame(_ frame: CGRect) {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: allAttributes.count, section: 0))
            attributes.frame = frame
            allAttributes.append(attributes)
        }
        let itemCount = collectionView!.numberOfItems(inSection: 0)
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
            var frame = CGRect(origin: .zero, size: itemSize)
            for _ in 0..<itemCount {
                appendAttributesWithFrame(frame)
                frame.origin.x += frame.width + interitemSpacing
                if frame.maxX > bounds.width {
                    frame.origin.x = 0
                    frame.origin.y += frame.height + lineSpacing
                }
            }
            
            let margin = (bounds.width - allAttributes.map({ $0.frame.maxX }).max()!) / 2
            for attributes in allAttributes {
                attributes.center.x += margin
            }
            
        } else {
            // The bottom row of the diagram
            var frame = CGRect(origin: .zero, size: itemSize)
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
            width: max(allAttributes.map({ $0.frame.maxX }).max()!, bounds.width),
            height: allAttributes.map({ $0.frame.maxY }).max()!
        )
    }
    
    override var collectionViewContentSize : CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return allAttributes.filter { rect.intersects($0.frame) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> (UICollectionViewLayoutAttributes!) {
        return allAttributes[(indexPath as NSIndexPath).item]
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return newBounds.width != collectionView!.bounds.width
    }
    
}
