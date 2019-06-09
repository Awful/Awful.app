//  Selectotron.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/**
A modal view controller for picking a particular page of a thread. By default it presents in a popover on all devices.
*/
final class Selectotron : ViewController {
    let postsViewController: PostsPageViewController
    
    @IBOutlet weak var jumpButton: UIButton!
    @IBOutlet weak var buttonRow: UIView!
    @IBOutlet weak var picker: UIPickerView!
    
    init(postsViewController: PostsPageViewController) {
        self.postsViewController = postsViewController
        super.init(nibName: "Selectotron", bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController!.delegate = self
    }
    
    @IBAction func firstPostButtonTapped() {
        dismissAndLoadPage(.first)
    }
    
    @IBAction func jumpButtonTapped() {
        let pageNumber = picker.selectedRow(inComponent: 0) + 1
        dismissAndLoadPage(.specific(pageNumber))
    }
    
    @IBAction func lastPostButtonTapped() {
        postsViewController.goToLastPost()
        dismiss(animated: true, completion: nil)
    }
    
    fileprivate func dismissAndLoadPage(_ page: ThreadPage) {
        postsViewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
        dismiss(animated: true, completion: nil)
    }
    
    var selectedPage: Int {
        get {
            return picker.selectedRow(inComponent: 0) + 1
        } set {
            picker.selectRow(newValue - 1, inComponent: 0, animated: false)
            updateJumpButtonTitle()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let preferredHeight = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.tintColor = theme["tintColor"]
        view.backgroundColor = theme["sheetBackgroundColor"]
        popoverPresentationController?.backgroundColor = theme["sheetBackgroundColor"]
        buttonRow.backgroundColor = theme["sheetTitleBackgroundColor"]
        picker.reloadAllComponents()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch postsViewController.page {
        case .last?:
            selectedPage = picker.numberOfRows(inComponent: 0)
        case .specific(let pageNumber)?:
            selectedPage = pageNumber
        case .nextUnread?, nil:
            break
        }
    }
    
    public func updateJumpButtonTitle() {
        let title = .specific(selectedPage) == postsViewController.page ? "Reload" : "Jump"
        jumpButton.setTitle(title, for: .normal)
    }
    
    fileprivate override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}

extension Selectotron: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension Selectotron: UIPickerViewDataSource, UIPickerViewAccessibilityDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Int(postsViewController.numberOfPages)
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let attributes = [
            NSAttributedString.Key.foregroundColor: theme["sheetTextColor"]!,
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        return NSAttributedString(string: "\(row + 1)", attributes: attributes)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        updateJumpButtonTitle()
    }
    
    func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? {
        return "Page \(component + 1)"
    }
}
