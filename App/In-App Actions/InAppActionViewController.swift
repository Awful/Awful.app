//  InAppActionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
An InAppActionViewController is a modal view controller offering various actions that can be performed on a selected item. By default, it displays in a popover on all devices.
*/
class InAppActionViewController: AwfulViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIPopoverPresentationControllerDelegate {
    
    var items: [AwfulIconActionItem] = [] {
        didSet {
            if isViewLoaded() {
                collectionView.reloadData()
            }
        }
    }
    
    @IBOutlet weak var headerBackground: UIView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    /**
        A block called to (re)position the popover during presentation.
    
        If non-nil, the block is called:
    
            * When the popover is first presented.
            * Whenever the popover is repositioned, such as after a size or orientation change.
    
        :param: sourceRect On input, the suggested target rectangle for the popover (in the coordinate space of the sourceView). Put a new value in this parameter to change the target rectangle.
        :param: sourceView On input, the suggested target view for the popover. Put a new view in this parameter to change the target view.
    */
    var popoverPositioningBlock: ((sourceRect: UnsafeMutablePointer<CGRect>, sourceView: AutoreleasingUnsafeMutablePointer<UIView?>) -> Void)?
    
    private var headerHeightConstraint: NSLayoutConstraint?
    
    override init(nibName: String!, bundle: NSBundle!) {
        super.init(nibName: nibName, bundle: bundle)
        modalPresentationStyle = .Popover
        popoverPresentationController!.delegate = self
    }
    
    convenience init() {
        self.init(nibName: "InAppActionSheet", bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    override var title: String! {
        didSet {
            if isViewLoaded() {
                headerLabel.text = title
                titleDidChange()
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        collectionView.registerClass(AwfulIconActionCell.self, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        headerLabel.text = title
        titleDidChange()
        recalculatePreferredContentSize()
    }
    
    private func titleDidChange() {
        if (title ?? "").characters.count == 0 {
            if headerHeightConstraint == nil {
                let constraint = NSLayoutConstraint(item: headerBackground, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 0)
                headerBackground.addConstraint(constraint)
                headerHeightConstraint = constraint
            }
        } else {
            if let constraint = headerHeightConstraint {
                headerBackground.removeConstraint(constraint)
                headerHeightConstraint = nil
            }
        }
        recalculatePreferredContentSize()
    }
    
    private func recalculatePreferredContentSize() {
        let preferredHeight = view.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["sheetBackgroundColor"]
        collectionView.backgroundColor = theme["sheetBackgroundColor"]
        headerLabel.textColor = theme["sheetTitleColor"]
        headerBackground.backgroundColor = theme["sheetTitleBackgroundColor"]
        collectionView.reloadItemsAtIndexPaths(collectionView.indexPathsForVisibleItems())
        collectionView.indicatorStyle = theme.scrollIndicatorStyle
        popoverPresentationController?.backgroundColor = theme["sheetBackgroundColor"]
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // TODO: Feels like this should be doable without code, thanks to iOS 8's runtime calculating of preferredMaxLayoutWidth, but I couldn't figure out how to get the headerLabel to go past line one.
        headerLabel.preferredMaxLayoutWidth = headerLabel.bounds.width
        view.layoutIfNeeded()
        
        recalculatePreferredContentSize()
    }
}

extension InAppActionViewController {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! AwfulIconActionCell
        cell.titleLabel.text = item.title
        cell.titleLabel.textColor = theme["sheetTextColor"]
        cell.iconImageView.image = item.icon
        cell.tintColor = theme[item.themeKey] ?? theme["actionIconTintColor"] ?? theme["tintColor"]
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = item.title
        cell.accessibilityTraits = UIAccessibilityTraitButton
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let item = items[indexPath.item]
        dismissViewControllerAnimated(true, completion: item.action)
    }
    
}

private let cellIdentifier = "Cell"

extension InAppActionViewController {
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
    func prepareForPopoverPresentation(popover: UIPopoverPresentationController) {
        if let block = popoverPositioningBlock {
            var sourceRect = popover.sourceRect
            var sourceView: UIView? = popover.sourceView
            block(sourceRect: &sourceRect, sourceView: &sourceView)
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
    }
    
    func popoverPresentationController(popover: UIPopoverPresentationController, willRepositionPopoverToRect rect: UnsafeMutablePointer<CGRect>, inView view: AutoreleasingUnsafeMutablePointer<UIView?>) {
        if let block = popoverPositioningBlock {
            block(sourceRect: rect, sourceView: view)
        }
    }
    
}
