//  SmileyKeyboardView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public class SmileyKeyboardView: UIView {

    public weak var delegate: SmileyKeyboardViewDelegate? {
        didSet { collectionView.reloadData() }
    }
    
    private let pageControl: UIPageControl
    private let collectionView: UICollectionView
    
    override public init(frame: CGRect) {
        pageControl = UIPageControl()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .Horizontal
        layout.estimatedItemSize = CGSize(width: 50, height: 30)
        collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        super.init(frame: frame)
        
        pageControl.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(pageControl)
        
        collectionView.dataSource = self
        collectionView.registerClass(KeyCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor(red:0.819, green:0.835, blue:0.858, alpha:1)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.pagingEnabled = true
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        collectionView.addObserver(self, forKeyPath: "contentSize", options: .New, context: KVOContext)
        addSubview(collectionView)
        
        let views = [
            "pages": pageControl,
            "keys": collectionView
        ]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[pages(16)][keys]|", options: .AlignAllCenterX, metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[keys]|", options: nil, metrics: nil, views: views))
        pageControl.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Vertical)
    }
    
    deinit {
        collectionView.removeObserver(self, forKeyPath: "contentSize", context: KVOContext)
    }
    
    override public func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if context == KVOContext {
            let contentSize = (change[NSKeyValueChangeNewKey] as NSValue).CGSizeValue()
            dispatch_async(dispatch_get_main_queue()) {
                self.pageControl.numberOfPages = Int(ceil(contentSize.width / self.collectionView.bounds.width))
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

private let KVOContext = UnsafeMutablePointer<Void>()

extension SmileyKeyboardView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.smileyKeyboard(self, numberOfKeysInSection: section) ?? 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as KeyCell
        if let data = delegate?.smileyKeyboard(self, imageDataForKeyAtIndexPath: indexPath) {
            cell.imageView.image = UIImage(data: data)
        }
        return cell
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.smileyKeyboard?(self, didTapKeyAtIndexPath: indexPath)
    }
    
}

class KeyCell: UICollectionViewCell {
    
    let imageView: UIImageView
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        super.init(frame: frame)
        
        imageView.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(imageView)
        
        let views = ["image": imageView]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[image]|", options: nil, metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[image]|", options: nil, metrics: nil, views: views))
        imageView.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        imageView.setContentCompressionResistancePriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        imageView.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Vertical)
        imageView.setContentCompressionResistancePriority(1000 /* UILayoutPriorityRequired */, forAxis: .Vertical)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private let cellIdentifier: String = "KeyCell"

@objc public protocol SmileyKeyboardViewDelegate {
    
    func smileyKeyboard(keyboardView: SmileyKeyboardView, numberOfKeysInSection section: Int) -> Int
    func smileyKeyboard(keyboardView: SmileyKeyboardView, imageDataForKeyAtIndexPath indexPath: NSIndexPath) -> NSData
    optional func smileyKeyboard(keyboardView: SmileyKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath)
    
}
