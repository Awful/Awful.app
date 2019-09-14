//  InAppActionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
An InAppActionViewController is a modal view controller offering various actions that can be performed on a selected item. By default, it displays in a popover on all devices.
*/
final class InAppActionViewController: ViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIPopoverPresentationControllerDelegate {
    
    var items: [IconActionItem] = [] {
        didSet {
            if isViewLoaded {
                collectionView.reloadData()
            }
        }
    }
    
    @IBOutlet private var headerBackground: UIView!
    @IBOutlet private var headerLabel: UILabel!
    @IBOutlet private var hideHeaderConstraint: NSLayoutConstraint!
    @IBOutlet private var collectionView: UICollectionView!
    
    /**
        A block called to (re)position the popover during presentation.
    
        If non-nil, the block is called:
    
            * When the popover is first presented.
            * Whenever the popover is repositioned, such as after a size or orientation change.
    
        - parameter sourceRect: On input, the suggested target rectangle for the popover (in the coordinate space of the sourceView). Put a new value in this parameter to change the target rectangle.
        - parameter sourceView: On input, the suggested target view for the popover. Put a new view in this parameter to change the target view.
    */
    var popoverPositioningBlock: ((_ sourceRect: UnsafeMutablePointer<CGRect>, _ sourceView: AutoreleasingUnsafeMutablePointer<UIView>) -> Void)?

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)

        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self
    }
    
    convenience init() {
        self.init(nibName: "InAppActionSheet", bundle: nil)
    }
    
    override var title: String? {
        didSet {
            if isViewLoaded {
                headerLabel.text = title
                titleDidChange()
            }
        }
    }

    override func viewDidLoad() {
        collectionView.register(IconActionCell.self, forCellWithReuseIdentifier: cellIdentifier)

        super.viewDidLoad()
        
        headerLabel.text = title
        titleDidChange()
        recalculatePreferredContentSize()
    }
    
    fileprivate func titleDidChange() {
        hideHeaderConstraint.isActive = (title ?? "").isEmpty
        recalculatePreferredContentSize()
    }
    
    fileprivate func recalculatePreferredContentSize() {
        let fittingSize = CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height)
        preferredContentSize = view.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultLow)
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

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}

extension InAppActionViewController {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return items.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath as IndexPath) as! IconActionCell
        cell.titleLabel.text = item.title
        cell.titleLabel.textColor = theme["sheetTextColor"]
        cell.iconImageView.image = item.icon
        cell.tintColor = theme[item.themeKey] ?? theme["actionIconTintColor"] ?? theme["tintColor"]
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = item.title
        cell.accessibilityTraits = UIAccessibilityTraits.button
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = items[indexPath.item]
        dismiss(animated: true, completion: item.block)
    }
}

private let cellIdentifier = "Cell"

extension InAppActionViewController {
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        return .none
    }
    
    func prepareForPopoverPresentation(_ popover: UIPopoverPresentationController) {
        if let block = popoverPositioningBlock {
            var sourceRect = popover.sourceRect
            var sourceView = popover.sourceView ?? UIView()
            block(&sourceRect, &sourceView)
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
    }

    func popoverPresentationController(
        _ popover: UIPopoverPresentationController,
        willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>,
        in view: AutoreleasingUnsafeMutablePointer<UIView>
    ) {
        popoverPositioningBlock?(rect, view)
    }
}
