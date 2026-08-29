//  PagePickerViewController.swift
//
//  Copyright © 2025 Awful Contributors. All rights reserved.
//

import AwfulTheming
import UIKit

/// A compact page-jump popover, mirroring the rap sheet's `PagePickerViewController` (itself a
/// trimmed clone of the posts page's `Selectotron`). Lives here because the rap sheet's picker is
/// fileprivate in another package.
final class PagePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIPopoverPresentationControllerDelegate {
    private let pageCount: Int
    private let initialPage: Int
    private let onSelect: (Int) -> Void
    private let picker = UIPickerView()

    init(
        pageCount: Int,
        currentPage: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        self.pageCount = pageCount
        self.initialPage = currentPage
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 240, height: 240)
        modalPresentationStyle = .popover
        // Stay a popover on iPhone too (like `Selectotron`); otherwise this adapts to a full-screen sheet.
        popoverPresentationController?.delegate = self
    }

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let theme = Theme.defaultTheme()
        view.backgroundColor = theme["sheetBackgroundColor"] ?? theme["backgroundColor"]

        picker.dataSource = self
        picker.delegate = self
        picker.selectRow(min(max(initialPage - 1, 0), pageCount - 1), inComponent: 0, animated: false)

        let goButton = UIButton(type: .system)
        goButton.setTitle(String(localized: "Go", bundle: .module), for: .normal)
        goButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        goButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let selected = self.picker.selectedRow(inComponent: 0) + 1
            self.dismiss(animated: true) { self.onSelect(selected) }
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [picker, goButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: -12),
        ])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { pageCount }

    /// Attributed titles (like `Selectotron`'s): plain titles render in the system label color, which can be
    /// invisible against the themed sheet background when the theme and system appearance disagree.
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let theme = Theme.defaultTheme()
        return NSAttributedString(string: "\(row + 1)", attributes: [
            .foregroundColor: theme[uicolor: "sheetTextColor"] ?? UIColor.label,
            .font: UIFont.preferredFont(forTextStyle: .body),
        ])
    }
}
