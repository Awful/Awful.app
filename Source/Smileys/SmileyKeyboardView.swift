//  SmileyKeyboardView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public class SmileyKeyboardView: UIView {

    public weak var delegate: SmileyKeyboardViewDelegate? {
        didSet { collectionView.reloadData() }
    }
    
    public let nextKeyboardButton: UIButton
    public let sectionPicker: UISegmentedControl
    public let deleteButton: UIButton
    
    private let pageControl: UIPageControl
    private let collectionView: UICollectionView
    
    override public init(frame: CGRect) {
        pageControl = UIPageControl()
        let layout = PaginatedHorizontalCollectionViewLayout()
        collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        nextKeyboardButton = UIButton()
        sectionPicker = UISegmentedControl()
        deleteButton = UIButton()
        super.init(frame: frame)
        
        pageControl.addTarget(self, action: "didTapPageControl:", forControlEvents: .ValueChanged)
        pageControl.backgroundColor = UIColor(red:0.819, green:0.835, blue:0.858, alpha:1)
        pageControl.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(pageControl)
        
        collectionView.dataSource = self
        collectionView.registerClass(KeyCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor(red:0.819, green:0.835, blue:0.858, alpha:1)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.pagingEnabled = true
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(collectionView)
        
        let imageURL = NSBundle(forClass: SmileyKeyboardView.self).URLForResource("next_keyboard@2x", withExtension: "png")
        var image = UIImage(contentsOfFile: imageURL!.path!)
        image = UIImage(CGImage: image.CGImage, scale: 2, orientation: image.imageOrientation)
        image = image.imageWithRenderingMode(.AlwaysTemplate)
        nextKeyboardButton.setImage(image, forState: .Normal)
        nextKeyboardButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        nextKeyboardButton.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        nextKeyboardButton.setContentCompressionResistancePriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        addSubview(nextKeyboardButton)
        
        sectionPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(sectionPicker)
        
        deleteButton.setTitle("⌫", forState: .Normal)
        deleteButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        deleteButton.setContentHuggingPriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        deleteButton.setContentCompressionResistancePriority(1000 /* UILayoutPriorityRequired */, forAxis: .Horizontal)
        addSubview(deleteButton)
        
        let views = [
            "pages": pageControl,
            "keys": collectionView,
            "next": nextKeyboardButton,
            "sections": sectionPicker,
            "delete": deleteButton
        ]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[pages(<=24)][keys][sections]|", options: .AlignAllCenterX, metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[keys]|", options: nil, metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[next][sections][delete]|", options: .AlignAllTop, metrics: nil, views: views))
        addConstraint(NSLayoutConstraint(item: nextKeyboardButton, attribute: .Bottom, relatedBy: .Equal, toItem: sectionPicker, attribute: .Bottom, multiplier: 1, constant: 0))
        addConstraint(NSLayoutConstraint(item: deleteButton, attribute: .Bottom, relatedBy: .Equal, toItem: sectionPicker, attribute: .Bottom, multiplier: 1, constant: 0))
    }
    
    @objc private func didTapPageControl(sender: UIPageControl) {
        var rect = collectionView.bounds
        rect.origin.x = rect.width * CGFloat(sender.currentPage)
        collectionView.scrollRectToVisible(rect, animated: true)
    }
    
    public func reloadData() {
        collectionView.reloadData()
    }

    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension SmileyKeyboardView: UICollectionViewDataSource, PaginatedHorizontalLayoutDelegate {
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.numberOfKeysInSmileyKeyboard(self) ?? 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as KeyCell
        if let data = delegate?.smileyKeyboard(self, imageDataForKeyAtIndexPath: indexPath) {
            
            // GIFs start with the string "GIF", and nothing else starts with "G". Assume all GIFs are animated; FLAnimatedImage will deal with single-frame GIFs.
            var firstByte: UInt8 = 0
            data.getBytes(&firstByte, length: 1)
            if firstByte == 0x47 {
                cell.imageView.animatedImage = FLAnimatedImage(animatedGIFData: data)
            } else {
                cell.imageView.image = UIImage(data: data)
            }
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, layout: PaginatedHorizontalCollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let data = delegate!.smileyKeyboard(self, imageDataForKeyAtIndexPath: indexPath)
        let image = UIImage(data: data)
        return image.size
    }
    
    func collectionView(collectionView: UICollectionView, numberOfPagesDidChangeInLayout layout: PaginatedHorizontalCollectionViewLayout) {
        pageControl.numberOfPages = layout.numberOfPages
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.smileyKeyboard?(self, didTapKeyAtIndexPath: indexPath)
        collectionView.deselectItemAtIndexPath(indexPath, animated: false)
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        let pageFraction = scrollView.contentOffset.x % pageWidth / pageWidth
        if pageFraction < 0.1 || pageFraction > 0.9 {
            let layout = collectionView.collectionViewLayout as PaginatedHorizontalCollectionViewLayout
            pageControl.currentPage = layout.currentPage
        }
    }
    
}

class KeyCell: UICollectionViewCell {
    
    let imageView: FLAnimatedImageView
    
    override init(frame: CGRect) {
        imageView = FLAnimatedImageView()
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
    
    func numberOfKeysInSmileyKeyboard(keyboardView: SmileyKeyboardView) -> Int
    func smileyKeyboard(keyboardView: SmileyKeyboardView, imageDataForKeyAtIndexPath indexPath: NSIndexPath) -> NSData
    optional func smileyKeyboard(keyboardView: SmileyKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath)
    
}
