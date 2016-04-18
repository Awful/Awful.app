//  ThreadTagPickerViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class ThreadTagPickerViewController: AwfulViewController {
    weak var delegate: ThreadTagPickerViewControllerDelegate?
    private let imageNames: [String]
    private let secondaryImageNames: [String]?
    private weak var presentingView: UIView?
    
    init(imageNames: [String], secondaryImageNames: [String]?) {
        self.imageNames = imageNames
        self.secondaryImageNames = secondaryImageNames
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func present(fromView view: UIView) {
        let presentedViewController: UIViewController
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            presentedViewController = self
        } else {
            presentedViewController = enclosingNavigationController
        }
        presentingView = view
        presentedViewController.modalPresentationStyle = .Popover
        view.nearestViewController?.presentViewController(presentedViewController, animated: true, completion: nil)
        
        if let popover = presentedViewController.popoverPresentationController {
            popover.delegate = self
            popover.permittedArrowDirections = [.Up, .Down]
            popover.sourceRect = view.bounds
            popover.sourceView = view
        }
    }
    
    func dismiss() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func selectImageName(imageName: String) {
        guard let item = imageNames.indexOf(imageName) else { return }
        let section = secondaryImageNames?.isEmpty == false ? 1 : 0
        collectionView.performBatchUpdates({
            let indexPath = NSIndexPath(forItem: item, inSection: section)
            self.collectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
    }
    
    func selectSecondaryImageName(imageName: String) {
        guard let secondaryImageNames = secondaryImageNames where !secondaryImageNames.isEmpty else { fatalError("thread tag picker isn't showing secondary tags") }
        guard let item = secondaryImageNames.indexOf(imageName) else { return }
        collectionView.performBatchUpdates({ 
            let indexPath = NSIndexPath(forItem: item, inSection: 0)
            self.collectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
    }
    
    private(set) lazy var cancelButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .Cancel, target: nil, action: nil)
        button.actionBlock = { [weak self] _ in
            self?.dismiss()
            self?.delegate?.threadTagPickerDidDismiss?(self!)
        }
        return button
    }()
    
    private(set) lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .Done, target: nil, action: nil)
        button.actionBlock = { [weak self] _ in
            self?.dismiss()
            self?.delegate?.threadTagPickerDidDismiss?(self!)
        }
        return button
    }()
    
    private var _collectionView: UICollectionView?
    var collectionView: UICollectionView {
        get {
            if _collectionView == nil {
                loadViewIfNeeded()
            }
            return _collectionView!
        }
        set {
            precondition(_collectionView == nil)
            _collectionView = newValue
        }
    }
    
    private var threadTagObservers: [Int: NewThreadTagObserver] = [:]
    
    private func isSecondaryTagSection(section: Int) -> Bool {
        return secondaryImageNames?.isEmpty == false && section == 0
    }
    
    private func ensureLoneSelectedCellInSectionAtIndexPath(indexPath: NSIndexPath) {
        for selectedIndexPath in collectionView.indexPathsForSelectedItems() ?? [] {
            if selectedIndexPath.section == indexPath.section && selectedIndexPath.item != indexPath.item {
                collectionView.deselectItemAtIndexPath(selectedIndexPath, animated: true)
            }
        }
    }
    
    override func loadView() {
        view = UIView()
        
        let layout = ThreadTagPickerLayout()
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        collectionView = UICollectionView(frame: CGRect(origin: .zero, size: view.bounds.size), collectionViewLayout: layout)
        collectionView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        collectionView.registerClass(ThreadTagPickerCell.self, forCellWithReuseIdentifier: cellID)
        collectionView.registerClass(SecondaryTagPickerCell.self, forCellWithReuseIdentifier: secondaryCellID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = secondaryImageNames?.isEmpty == false
        view.addSubview(collectionView)
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        let popoverCornerRadius: CGFloat = 10
        collectionView.contentInset = UIEdgeInsets(top: popoverCornerRadius, left: 0, bottom: popoverCornerRadius, right: 0)
    }
}

extension ThreadTagPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return secondaryImageNames?.isEmpty == false ? 2 : 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isSecondaryTagSection(section) {
            return secondaryImageNames?.count ?? 0
        }
        return imageNames.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if isSecondaryTagSection(indexPath.section) {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(secondaryCellID, forIndexPath: indexPath) as! SecondaryTagPickerCell
            cell.titleTextColor = theme["tagPickerTextColor"] ?? .blackColor()
            cell.tagImageName = secondaryImageNames![indexPath.item]
            return cell
        }
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellID, forIndexPath: indexPath) as! ThreadTagPickerCell
        let imageName = imageNames[indexPath.item]
        let image = ThreadTagLoader.imageNamed(imageName)
        cell.image = image ?? ThreadTagLoader.emptyThreadTagImage
        
        if image == nil {
            cell.tagImageName = (imageName as NSString).stringByDeletingPathExtension
            threadTagObservers[indexPath.item] = NewThreadTagObserver(imageName: imageName, downloadedBlock: { [weak self] (image) in
                if let
                    collectionView = self?.collectionView,
                    currentIndexPath = collectionView.indexPathForCell(cell)
                    where currentIndexPath.item == indexPath.item
                {
                    cell.image = image
                    cell.tagImageName = nil
                }
                self?.threadTagObservers.removeValueForKey(indexPath.item)
            })
        } else {
            cell.tagImageName = nil
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.performBatchUpdates({ 
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
        
        if isSecondaryTagSection(indexPath.section) {
            delegate?.threadTagPicker?(self, didSelectSecondaryImageName: secondaryImageNames![indexPath.item])
        } else {
            delegate?.threadTagPicker(self, didSelectImageName: imageNames[indexPath.item])
        }
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        if isSecondaryTagSection(section) {
            return UIEdgeInsets(top: 0, left: 0, bottom: 15, right: 0)
        }
        return UIEdgeInsets()
    }
}

private let cellID = "Cell"
private let secondaryCellID = "Secondary"

extension ThreadTagPickerViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationController(popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverToRect rect: UnsafeMutablePointer<CGRect>, inView view: AutoreleasingUnsafeMutablePointer<UIView?>) {
        view.memory = presentingView
        rect.memory = presentingView?.bounds ?? .zero
    }
    
    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        delegate?.threadTagPickerDidDismiss?(self)
    }
}

@objc protocol ThreadTagPickerViewControllerDelegate: class {
    func threadTagPicker(picker: ThreadTagPickerViewController, didSelectImageName imageName: String)
    
    optional func threadTagPicker(picker: ThreadTagPickerViewController, didSelectSecondaryImageName imageName: String)
    
    optional func threadTagPickerDidDismiss(picker: ThreadTagPickerViewController)
}
