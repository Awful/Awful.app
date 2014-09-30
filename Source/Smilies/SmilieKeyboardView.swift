//  SmilieKeyboardView.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public class SmilieKeyboardView: UIView {
    
    public weak var delegate: SmilieKeyboardViewDelegate? {
        didSet { setNeedsLayout() }
    }
    
    private(set) public var numberOfSections: Int = 0
    
    public var selectedSection: Int = 0 {
        didSet {
            sectionPicker.selectedSegmentIndex = selectedSection
            collectionView.reloadData()
        }
    }
    
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var nextKeyboardButton: UIButton!
    @IBOutlet private weak var sectionPicker: UISegmentedControl!
    @IBOutlet private weak var deleteButton: UIButton!
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.registerClass(KeyCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.contentInset.left = 5
        collectionView.contentInset.right = 5
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if numberOfSections == 0 {
            reloadData()
        }
    }
    
    private func scrollToPage(page: Int) {
        var rect = collectionView.bounds
        rect.origin.x = rect.width * CGFloat(page)
        collectionView.scrollRectToVisible(rect, animated: true)
    }
    
    @IBAction private func didTapPageControl(sender: UIPageControl) {
        scrollToPage(sender.currentPage)
    }
    
    @IBAction func didTapNextKeyboardButton() {
        delegate?.advanceToNextKeyboardFromSmilieKeyboard(self)
    }
    
    @IBAction func didTapSectionPicker() {
        if sectionPicker.selectedSegmentIndex == selectedSection {
            scrollToPage(0)
        } else {
            selectedSection = sectionPicker.selectedSegmentIndex
        }
    }
    
    @IBAction func didTapDeleteButton() {
        delegate?.deleteBackwardForSmilieKeyboard(self)
    }
    
    public func reloadData() {
        numberOfSections = delegate?.numberOfSectionsInSmilieKeyboard(self) ?? 0
        sectionPicker.removeAllSegments()
        for i in 0 ..< numberOfSections {
            let title = delegate!.smilieKeyboard(self, titleForSection: i)
            sectionPicker.insertSegmentWithTitle(title, atIndex: i, animated: false)
        }
        
        if selectedSection >= numberOfSections {
            selectedSection = max(numberOfSections - 1, 0)
        } else {
            sectionPicker.selectedSegmentIndex = selectedSection
            collectionView.reloadData()
        }
    }
    
}

extension SmilieKeyboardView: UICollectionViewDataSource, PaginatedHorizontalLayoutDelegate {
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.smilieKeyboard(self, numberOfKeysInSection: selectedSection) ?? 0
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as KeyCell
        if let data = delegate?.smilieKeyboard(self, imageDataForKeyAtIndexPath: indexPath) {
            
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
        let data = delegate!.smilieKeyboard(self, imageDataForKeyAtIndexPath: indexPath)
        let image = UIImage(data: data)
        return image.size
    }
    
    func collectionView(collectionView: UICollectionView, numberOfPagesDidChangeInLayout layout: PaginatedHorizontalCollectionViewLayout) {
        pageControl.numberOfPages = layout.numberOfPages
    }
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.smilieKeyboard(self, didTapKeyAtIndexPath: indexPath)
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

@IBDesignable
class BottomButton: UIButton {
    
    private var didAwake = false
    
    private var normalBackgroundColor: UIColor!
    
    @IBInspectable var selectedBackgroundColor: UIColor? {
        didSet {
            updateBackgroundColor()
        }
    }
    
    override var highlighted: Bool {
        didSet {
            updateBackgroundColor()
        }
    }
    
    override var selected: Bool {
        didSet {
            updateBackgroundColor()
        }
    }
    
    private func updateBackgroundColor() {
        if !didAwake { return }
        
        if highlighted || selected {
            backgroundColor = selectedBackgroundColor
        } else {
            backgroundColor = normalBackgroundColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        normalBackgroundColor = backgroundColor
        didAwake = true
        updateBackgroundColor()
    }
    
}

@objc public protocol SmilieKeyboardViewDelegate {
    
    func numberOfSectionsInSmilieKeyboard(keyboardView: SmilieKeyboardView) -> Int
    func smilieKeyboard(keyboardView: SmilieKeyboardView, titleForSection section: Int) -> NSString
    func smilieKeyboard(keyboardView: SmilieKeyboardView, numberOfKeysInSection section: Int) -> Int
    func smilieKeyboard(keyboardView: SmilieKeyboardView, imageDataForKeyAtIndexPath indexPath: NSIndexPath) -> NSData
    
    func smilieKeyboard(keyboardView: SmilieKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath)
    func deleteBackwardForSmilieKeyboard(keyboardView: SmilieKeyboardView)
    func advanceToNextKeyboardFromSmilieKeyboard(keyboardView: SmilieKeyboardView)
    
}
