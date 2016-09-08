//  ThreadTagPickerViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class ThreadTagPickerViewController: ViewController {
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
        if UIDevice.current.userInterfaceIdiom == .Pad {
            presentedViewController = self
        } else {
            presentedViewController = enclosingNavigationController
        }
        presentingView = view
        presentedViewController.modalPresentationStyle = .popover
        view.nearestViewController?.present(presentedViewController, animated: true, completion: nil)
        
        if let popover = presentedViewController.popoverPresentationController {
            popover.delegate = self
            popover.permittedArrowDirections = [.Up, .down]
            popover.sourceRect = view.bounds
            popover.sourceView = view
        }
    }
    
    func dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    func selectImageName(imageName: String) {
        guard let item = imageNames.index(of: imageName) else { return }
        let section = secondaryImageNames?.isEmpty == false ? 1 : 0
        collectionView.performBatchUpdates({
            let indexPath = NSIndexPath(forItem: item, inSection: section)
            self.collectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
    }
    
    func selectSecondaryImageName(imageName: String) {
        guard let secondaryImageNames = secondaryImageNames , !secondaryImageNames.isEmpty else { fatalError("thread tag picker isn't showing secondary tags") }
        guard let item = secondaryImageNames.index(of: imageName) else { return }
        collectionView.performBatchUpdates({ 
            let indexPath = NSIndexPath(forItem: item, inSection: 0)
            self.collectionView.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
    }
    
    private(set) lazy var cancelButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: nil, action: nil)
        button.actionBlock = { [weak self] _ in
            self?.dismiss()
            self?.delegate?.threadTagPickerDidDismiss?(picker: self!)
        }
        return button
    }()
    
    private(set) lazy var doneButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
        button.actionBlock = { [weak self] _ in
            self?.dismiss()
            self?.delegate?.threadTagPickerDidDismiss?(picker: self!)
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
        for selectedIndexPath in collectionView.indexPathsForSelectedItems ?? [] {
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
        collectionView.autoresizingMask = [.flexibleWidth, .FlexibleHeight]
        collectionView.register(ThreadTagPickerCell.self, forCellWithReuseIdentifier: cellID)
        collectionView.register(SecondaryTagPickerCell.self, forCellWithReuseIdentifier: secondaryCellID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = secondaryImageNames?.isEmpty == false
        view.addSubview(collectionView)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        let popoverCornerRadius: CGFloat = 10
        collectionView.contentInset = UIEdgeInsets(top: popoverCornerRadius, left: 0, bottom: popoverCornerRadius, right: 0)
    }
}

extension ThreadTagPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return selectSecondaryImageName.isEmpty == false ? 2 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isSecondaryTagSection(section) {
            return selectSecondaryImageName.count ?? 0
        }
        return imageNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isSecondaryTagSection(indexPath.section) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: secondaryCellID, for: indexPath as IndexPath) as! SecondaryTagPickerCell
            cell.titleTextColor = theme["tagPickerTextColor"] ?? .blackColor()
            cell.tagImageName = selectSecondaryImageName[indexPath.item]
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath as IndexPath) as! ThreadTagPickerCell
        let imageName = imageNames[indexPath.item]
        let image = ThreadTagLoader.imageNamed(imageName)
        cell.image = image ?? ThreadTagLoader.emptyThreadTagImage
        
        if image == nil {
            cell.tagImageName = (imageName as NSString).stringByDeletingPathExtension
            threadTagObservers[indexPath.item] = NewThreadTagObserver(imageName: imageName, downloadedBlock: { [weak self] (image) in
                if let
                    collectionView = self?.collectionView,
                    let currentIndexPath = collectionView.indexPathForCell(cell),
                    currentIndexPath.item == indexPath.item
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
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: IndexPath) {
        collectionView.performBatchUpdates({ 
            self.ensureLoneSelectedCellInSectionAtIndexPath(indexPath)
            }, completion: nil)
        
        if isSecondaryTagSection(indexPath.section) {
            delegate?.threadTagPicker?(picker: self, didSelectSecondaryImageName: selectSecondaryImageName![indexPath.item])
        } else {
            delegate?.threadTagPicker(self, didSelectImageName: imageNames[indexPath.item])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if isSecondaryTagSection(section) {
            return UIEdgeInsets(top: 0, left: 0, bottom: 15, right: 0)
        }
        return UIEdgeInsets()
    }
}

private let cellID = "Cell"
private let secondaryCellID = "Secondary"

extension ThreadTagPickerViewController: UIPopoverPresentationControllerDelegate {
    private func popoverPresentationController(popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverToRect rect: UnsafeMutablePointer<CGRect>, inView view: AutoreleasingUnsafeMutablePointer<UIView?>) {
        view.memory = presentingView
        rect.memory = presentingView?.bounds ?? .zero
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        delegate?.threadTagPickerDidDismiss?(picker: self)
    }
}

@objc protocol ThreadTagPickerViewControllerDelegate: class {
    func threadTagPicker(picker: ThreadTagPickerViewController, didSelectImageName imageName: String)
    
    @objc optional func threadTagPicker(picker: ThreadTagPickerViewController, didSelectSecondaryImageName imageName: String)
    
    @objc optional func threadTagPickerDidDismiss(picker: ThreadTagPickerViewController)
}
