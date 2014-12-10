//  Selectotron.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
A modal view controller for picking a particular page of a thread. By default it presents in a popover on all devices.
*/
final class Selectotron : AwfulViewController {
    let postsViewController: PostsPageViewController
    
    @IBOutlet weak var jumpButton: UIButton!
    @IBOutlet weak var buttonRow: UIView!
    @IBOutlet weak var picker: UIPickerView!
    
    init(postsViewController: PostsPageViewController) {
        self.postsViewController = postsViewController
        super.init(nibName: "Selectotron", bundle: nil)
        modalPresentationStyle = .Popover
        popoverPresentationController!.delegate = self
    }
    
    @IBAction func firstPostButtonTapped() {
        dismissAndLoadPage(1)
    }
    
    @IBAction func jumpButtonTapped() {
        let page = picker.selectedRowInComponent(0) + 1
        dismissAndLoadPage(page)
    }
    
    @IBAction func lastPostButtonTapped() {
        dismissAndLoadPage(AwfulThreadPage.Last.rawValue)
    }
    
    private func dismissAndLoadPage(page: Int) {
        postsViewController.loadPage(page, updatingCache: true)
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    var selectedPage: Int {
        get {
            return picker.selectedRowInComponent(0) + 1
        } set {
            picker.selectRow(newValue - 1, inComponent: 0, animated: false)
            updateJumpButtonTitle()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let preferredHeight = view.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.tintColor = theme["tintColor"] as UIColor?
        let backgroundColor = theme["sheetBackgroundColor"] as UIColor?
        view.backgroundColor = backgroundColor
        popoverPresentationController?.backgroundColor = backgroundColor
        buttonRow.backgroundColor = theme["sheetTitleBackgroundColor"] as UIColor?
        picker.reloadAllComponents()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let page = postsViewController.page
        switch page {
        case AwfulThreadPage.Last.rawValue:
            selectedPage = picker.numberOfRowsInComponent(0)
        case AwfulThreadPage.NextUnread.rawValue, AwfulThreadPage.None.rawValue:
            break
        default:
            selectedPage = page
        }
    }
    
    private func updateJumpButtonTitle() {
        let title = selectedPage == postsViewController.page ? "Reload" : "Jump"
        jumpButton.setTitle(title, forState: .Normal)
    }
    
    private override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        fatalError("Selectotron needs a posts view controller")
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
}

extension Selectotron: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController!) -> UIModalPresentationStyle {
        return .None
    }
}

extension Selectotron: UIPickerViewDataSource, UIPickerViewAccessibilityDelegate {
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Int(postsViewController.numberOfPages)
    }
    
    func pickerView(pickerView: UIPickerView!, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString! {
        let attributes = [
            NSForegroundColorAttributeName: theme["sheetTextColor"],
            NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        ]
        return NSAttributedString(string: "\(row + 1)", attributes: attributes)
    }
    
    func pickerView(pickerView: UIPickerView!, didSelectRow row: Int, inComponent component: Int) {
        updateJumpButtonTitle()
    }
    
    func pickerView(pickerView: UIPickerView!, accessibilityLabelForComponent component: Int) -> String! {
        return "Page \(component + 1)"
    }
}
