//  InAppActionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
An InAppActionViewController is a modal view controller offering various actions that can be performed on a selected item. By default, it displays in a popover on all devices.
*/
class InAppActionViewController: ViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIPopoverPresentationControllerDelegate {
    
    var items: [IconActionItem] = [] {
        didSet {
            if isViewLoaded {
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
    
        - parameter sourceRect: On input, the suggested target rectangle for the popover (in the coordinate space of the sourceView). Put a new value in this parameter to change the target rectangle.
        - parameter sourceView: On input, the suggested target view for the popover. Put a new view in this parameter to change the target view.
    */
    var popoverPositioningBlock: ((_ sourceRect: UnsafeMutablePointer<CGRect>, _ sourceView: AutoreleasingUnsafeMutablePointer<UIView>) -> Void)?
    
    fileprivate var headerHeightConstraint: NSLayoutConstraint?
    
    override init(nibName: String!, bundle: Bundle!) {
        super.init(nibName: nibName, bundle: bundle)
        modalPresentationStyle = .popover
        popoverPresentationController!.delegate = self
    }
    
    convenience init() {
        self.init(nibName: "InAppActionSheet", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    override var title: String! {
        didSet {
            if isViewLoaded {
                headerLabel.text = title
                titleDidChange()
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        collectionView.register(IconActionCell.self, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        headerLabel.text = title
        titleDidChange()
        recalculatePreferredContentSize()
    }
    
    fileprivate func titleDidChange() {
        if (title ?? "").characters.count == 0 {
            if headerHeightConstraint == nil {
                let constraint = NSLayoutConstraint(item: headerBackground, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
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
    
    fileprivate func recalculatePreferredContentSize() {
        let preferredHeight = view.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["sheetBackgroundColor"]
        collectionView.backgroundColor = theme["sheetBackgroundColor"]
        headerLabel.textColor = theme["sheetTitleColor"]
        headerBackground.backgroundColor = theme["sheetTitleBackgroundColor"]
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
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
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    @objc(collectionView:cellForItemAtIndexPath:)
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath as IndexPath) as! IconActionCell
        cell.titleLabel.text = item.title
        cell.titleLabel.textColor = theme["sheetTextColor"]
        cell.iconImageView.image = item.icon
        cell.tintColor = theme[item.themeKey] ?? theme["actionIconTintColor"] ?? theme["tintColor"]
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = item.title
        cell.accessibilityTraits = UIAccessibilityTraitButton
        return cell
    }
    
    @objc(collectionView:didSelectItemAtIndexPath:)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        dismiss(animated: true, completion: item.block)
    }
}

private let cellIdentifier = "Cell"

extension InAppActionViewController {
    @objc(adaptivePresentationStyleForPresentationController:)
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func prepareForPopoverPresentation(_ popover: UIPopoverPresentationController) {
        if let block = popoverPositioningBlock {
            var sourceRect = popover.sourceRect
            var sourceView = popover.sourceView!
            block(&sourceRect, &sourceView)
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
    }
    
    @objc(popoverPresentationController:willRepositionPopoverToRect:inView:)
    func popoverPresentationController(_ popover: UIPopoverPresentationController, willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>, in view: AutoreleasingUnsafeMutablePointer<UIView>) {
        if let block = popoverPositioningBlock {
            block(rect, view)
        }
    }
}
