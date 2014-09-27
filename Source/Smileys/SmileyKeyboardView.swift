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
    
    public override init(frame: CGRect) {
        pageControl = UIPageControl()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .Horizontal
        collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        super.init(frame: frame)
        
        pageControl.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(pageControl)
        
        collectionView.dataSource = self
        collectionView.registerClass(KeyCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.pagingEnabled = true
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(collectionView)
        
        let views = [
            "pages": pageControl,
            "keys": collectionView
        ]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[pages][keys]|", options: .AlignAllCenterX, metrics: nil, views: views))
        pageControl.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Vertical)
        
        backgroundColor = UIColor.greenColor()
        pageControl.backgroundColor = UIColor.purpleColor()
        collectionView.backgroundColor = UIColor.orangeColor()
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension SmileyKeyboardView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.smileyKeyboard(self, numberOfKeysInSection: section) ?? 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as KeyCell
        cell.imageView.image = delegate?.smileyKeyboard(self, imageForKeyAtIndexPath: indexPath)
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
    func smileyKeyboard(keyboardView: SmileyKeyboardView, imageForKeyAtIndexPath indexPath: NSIndexPath) -> UIImage!
    optional func smileyKeyboard(keyboardView: SmileyKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath)
    
}
