//  Selectotron.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import UIKit

/**
A modal view controller for picking a particular page of a thread. By default it presents in a popover on all devices.

Built entirely in code: the original Xcode 6-era XIB's decoded constraints proved impossible to
extend reliably (deactivating them by identity silently failed at runtime), so the whole layout
lives here now.
*/
final class Selectotron : ViewController {
    let postsViewController: PostsPageViewController

    private let buttonRow = UIView()
    private let firstPostButton = UIButton(type: .system)
    private let jumpButton = UIButton(type: .system)
    private let lastPostButton = UIButton(type: .system)
    private let picker = UIPickerView()

    @FoilDefaultStorage(Settings.endlessScrollPosts) private var endlessScrollPosts
    private let endlessScrollButton = UIButton(type: .system)

    init(postsViewController: PostsPageViewController) {
        self.postsViewController = postsViewController
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController!.delegate = self
    }

    private func firstPostButtonTapped() {
        dismissAndLoadPage(.first)
    }

    private func jumpButtonTapped() {
        let pageNumber = picker.selectedRow(inComponent: 0) + 1
        dismissAndLoadPage(.specific(pageNumber))
    }

    private func lastPostButtonTapped() {
        postsViewController.goToLastPost()
        dismiss(animated: true, completion: nil)
    }

    fileprivate func dismissAndLoadPage(_ page: ThreadPage) {
        postsViewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
        dismiss(animated: true, completion: nil)
    }

    private var selectedPage: Int {
        get {
            return picker.selectedRow(inComponent: 0) + 1
        } set {
            picker.selectRow(newValue - 1, inComponent: 0, animated: false)
            updateJumpButtonTitle()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let bodyFont = UIFont.preferredFontForTextStyle(.body, weight: .regular)

        firstPostButton.setTitle("First Post", for: .normal)
        firstPostButton.titleLabel?.font = bodyFont
        firstPostButton.addAction(UIAction { [weak self] _ in self?.firstPostButtonTapped() }, for: .touchUpInside)

        jumpButton.titleLabel?.font = bodyFont
        jumpButton.accessibilityHint = "Jump to selected page"
        jumpButton.addAction(UIAction { [weak self] _ in self?.jumpButtonTapped() }, for: .touchUpInside)

        lastPostButton.setTitle("Last Post", for: .normal)
        lastPostButton.titleLabel?.font = bodyFont
        lastPostButton.addAction(UIAction { [weak self] _ in self?.lastPostButtonTapped() }, for: .touchUpInside)

        endlessScrollButton.setTitle(endlessScrollPosts ? "Exit Endless Scroll" : "Start Endless Scroll", for: .normal)
        endlessScrollButton.titleLabel?.font = UIFont.preferredFontForTextStyle(.body, weight: .medium)
        endlessScrollButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.endlessScrollPosts.toggle()
            self.dismiss(animated: true)
        }, for: .touchUpInside)
        // If the presented popover comes out taller than the fitting size, force the slack into this
        // button (whose centered title makes the stretch invisible) rather than the other views.
        endlessScrollButton.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)

        picker.dataSource = self
        picker.delegate = self

        for button in [firstPostButton, jumpButton, lastPostButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            buttonRow.addSubview(button)
        }
        for subview in [buttonRow, picker, endlessScrollButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            buttonRow.topAnchor.constraint(equalTo: view.topAnchor),
            buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonRow.heightAnchor.constraint(equalToConstant: 44),

            firstPostButton.leadingAnchor.constraint(equalTo: buttonRow.leadingAnchor, constant: 12),
            firstPostButton.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
            jumpButton.centerXAnchor.constraint(equalTo: buttonRow.centerXAnchor),
            jumpButton.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
            lastPostButton.trailingAnchor.constraint(equalTo: buttonRow.trailingAnchor, constant: -12),
            lastPostButton.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),

            picker.topAnchor.constraint(equalTo: buttonRow.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.heightAnchor.constraint(equalToConstant: 162),

            endlessScrollButton.topAnchor.constraint(equalTo: picker.bottomAnchor),
            endlessScrollButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            endlessScrollButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            endlessScrollButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        let preferredHeight = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        preferredContentSize = CGSize(width: 320, height: preferredHeight)

        // `viewWillAppear` only sets `selectedPage` (which updates the title) for known page numbers,
        // so give the button a title for the `.nextUnread`/nil cases too.
        updateJumpButtonTitle()
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

    private func updateJumpButtonTitle() {
        let title = .specific(selectedPage) == postsViewController.page ? "Reload" : "Jump"
        jumpButton.setTitle(title, for: .normal)
        jumpButton.titleLabel?.font = UIFont.preferredFontForTextStyle(.body, weight: .medium)
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
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .regular)
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
