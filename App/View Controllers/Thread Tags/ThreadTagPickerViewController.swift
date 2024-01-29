//  ThreadTagPickerViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import UIKit

/**
 Shows a grid of thread tags (and, as needed, secondary thread tags) for the user to select.
 
 Useful when filtering threads in a forum; when making new posts; and when composing a private message.
 */
final class ThreadTagPickerViewController: ViewController {
    
    weak var delegate: ThreadTagPickerViewControllerDelegate?
    
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private let firstTag: ThreadTagLoader.Placeholder
    private let imageNames: [String]
    private let secondaryImageNames: [String]
    
    private weak var presentingView: UIView?
    
    init(firstTag: ThreadTagLoader.Placeholder, imageNames: [String], secondaryImageNames: [String]) {
        self.firstTag = firstTag
        self.imageNames = imageNames
        self.secondaryImageNames = secondaryImageNames
        super.init(nibName: nil, bundle: nil)
    }
    
    // MARK: Bar button items
    
    private(set) lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
    }()
    
    @objc private func didTapCancel(_ sender: UIBarButtonItem) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss()
        delegate?.didDismissPicker(self)
    }
    
    private(set) lazy var doneButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
    }()
    
    @objc private func didTapDone(_ sender: UIBarButtonItem) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss()
        delegate?.didDismissPicker(self)
    }
    
    // MARK: Presentation
    
    /// Presents the picker. If presented in a popover, attempts to keep the popover pointing at `view`.
    func present(from presentingViewController: UIViewController, sourceView: UIView) {
        presentingView = view
        
        let presentedViewController: UIViewController
        if UIDevice.current.userInterfaceIdiom == .pad {
            presentedViewController = self
        } else {
            presentedViewController = enclosingNavigationController
        }
        presentedViewController.modalPresentationStyle = .popover
        presentingViewController.present(presentedViewController, animated: true)
        
        if let popover = presentedViewController.popoverPresentationController {
            popover.delegate = self
            popover.permittedArrowDirections = [.up, .down]
            popover.sourceRect = sourceView.bounds
            popover.sourceView = sourceView
        }
    }
    
    func dismiss() {
        dismiss(animated: true)
    }
    
    // MARK: Selection
    
    private enum Section: Int, CaseIterable {
        case secondaryTag, threadTag
    }
    
    func selectImageName(_ imageName: String?) {
        guard let indexPath = indexPathForImageName(imageName) else { return }

        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        ensureLoneSelectedCellInSection(at: indexPath)
    }
    
    private func indexPathForImageName(_ imageName: String?) -> IndexPath? {
        if let imageName = imageName {
            let item = imageNames.firstIndex(of: imageName)
            return item.map { IndexPath(item: $0 + 1, section: Section.threadTag.rawValue) }
        } else {
            return IndexPath(item: 0, section: Section.threadTag.rawValue)
        }
        
    }
    
    func selectSecondaryImageName(_ imageName: String) {
        guard let indexPath = indexPathForSecondaryImageName(imageName) else { return }

        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        ensureLoneSelectedCellInSection(at: indexPath)
    }
    
    private func indexPathForSecondaryImageName(_ secondaryImageName: String) -> IndexPath? {
        guard let item = secondaryImageNames.firstIndex(of: secondaryImageName) else {
            return nil
        }
        return IndexPath(item: item, section: Section.secondaryTag.rawValue)
    }
    
    private func ensureLoneSelectedCellInSection(at indexPath: IndexPath) {
        for selectedIndexPath in collectionView.indexPathsForSelectedItems ?? [] {
            if selectedIndexPath.section == indexPath.section && selectedIndexPath.item != indexPath.item {
                collectionView.deselectItem(at: selectedIndexPath, animated: true)
            }
        }
    }
    
    // MARK: View lifecycle
    
    private lazy var collectionView: UICollectionView = {
        let layout = ThreadTagPickerLayout()
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SecondaryThreadTagPickerCell.self, forCellWithReuseIdentifier: secondaryCellID)
        collectionView.register(ThreadTagPickerCell.self, forCellWithReuseIdentifier: cellID)
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(collectionView, constrainEdges: .all)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        collectionView.flashScrollIndicators()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        let popoverCornerRadius: CGFloat = 10
        collectionView.contentInset = UIEdgeInsets(top: popoverCornerRadius, left: 0, bottom: popoverCornerRadius, right: 0)
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ThreadTagPickerViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .secondaryTag:
            return secondaryImageNames.count
        case .threadTag:
            return imageNames.count + 1 // firstTag placeholder
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .secondaryTag:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: secondaryCellID, for: indexPath as IndexPath) as! SecondaryThreadTagPickerCell
            cell.tagImageName = secondaryImageNames[indexPath.item]
            cell.titleTextColor = theme["tagPickerTextColor"] ?? .black
            return cell
            
        case .threadTag where indexPath.item == 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath as IndexPath) as! ThreadTagPickerCell
            cell.configure(placeholder: firstTag)
            return cell
            
        case .threadTag:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath as IndexPath) as! ThreadTagPickerCell
            cell.configure(tagImageName: imageNames[indexPath.item - 1])
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        ensureLoneSelectedCellInSection(at: indexPath)
        
        switch Section(rawValue: indexPath.section)! {
        case .secondaryTag:
            delegate?.didSelectSecondaryImageName(secondaryImageNames[indexPath.item], in: self)
        case .threadTag where indexPath.item == 0:
            delegate?.didSelectImageName(nil, in: self)
        case .threadTag:
            delegate?.didSelectImageName(imageNames[indexPath.item - 1], in: self)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        switch Section(rawValue: section)! {
        case .secondaryTag where !secondaryImageNames.isEmpty:
            return UIEdgeInsets(top: 0, left: 0, bottom: 15, right: 0)
        case .secondaryTag, .threadTag:
            return .zero
        }
    }
}

private let cellID = "Cell"
private let secondaryCellID = "Secondary"

extension ThreadTagPickerViewController: UIPopoverPresentationControllerDelegate {
    private func popoverPresentationController(_ popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverToRect rect: UnsafeMutablePointer<CGRect>, inView view: AutoreleasingUnsafeMutablePointer<UIView?>) {
        view.pointee = presentingView
        rect.pointee = presentingView?.bounds ?? .zero
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        delegate?.didDismissPicker(self)
    }
}

protocol ThreadTagPickerViewControllerDelegate: AnyObject {
    func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController)
    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController)
    func didDismissPicker(_ picker: ThreadTagPickerViewController)
}
