//  MessageFolderPickerView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import AwfulCore
import AwfulTheming

protocol MessageFolderPickerViewDelegate: AnyObject {
    func folderPicker(_ picker: MessageFolderPickerView, didSelectFolder folder: PrivateMessageFolder)
    func folderPickerDidRequestManageFolders(_ picker: MessageFolderPickerView)
}

final class MessageFolderPickerView: UIView {

    weak var delegate: MessageFolderPickerViewDelegate?

    private let segmentedControl: UISegmentedControl
    private var allFolders: [PrivateMessageFolder] = []
    private var currentFolder: PrivateMessageFolder?

    override init(frame: CGRect) {
        self.segmentedControl = UISegmentedControl(items: [
            LocalizedString("private-message-folder.inbox"),
            LocalizedString("private-message-folder.sent"),
            LocalizedString("private-message-folder.more")
        ])

        super.init(frame: frame)

        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        // Detect taps on segment 2 when it's already selected so the menu re-opens.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSegmentTap(_:)))
        tapGesture.delegate = self
        segmentedControl.addGestureRecognizer(tapGesture)

        segmentedControl.apportionsSegmentWidthsByContent = true

        backgroundColor = .clear
        isOpaque = false

        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func segmentChanged() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            if let folder = allFolders.first(where: { $0.folderID == "0" }) {
                currentFolder = folder
                delegate?.folderPicker(self, didSelectFolder: folder)
            }
        case 1:
            if let folder = allFolders.first(where: { $0.folderID == "-1" }) {
                currentFolder = folder
                delegate?.folderPicker(self, didSelectFolder: folder)
            }
        case 2:
            // If segment 2 currently displays a custom folder name, reselect that folder.
            // Otherwise open the folders menu.
            let segmentTitle = segmentedControl.titleForSegment(at: 2) ?? ""
            let defaultTitle = LocalizedString("private-message-folder.more")

            if segmentTitle != defaultTitle,
               let customFolder = allFolders.first(where: { $0.name == segmentTitle && $0.isCustom }) {
                currentFolder = customFolder
                delegate?.folderPicker(self, didSelectFolder: customFolder)
            } else {
                showFoldersMenu()
            }
        default:
            break
        }
    }

    private func showFoldersMenu() {
        guard let viewController = findViewController() else {
            restorePreviousSelection()
            return
        }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let menuAppearance = Theme.defaultTheme()[string: "menuAppearance"]
        alertController.overrideUserInterfaceStyle = menuAppearance == "light" ? .light : .dark

        for folder in allFolders where folder.isCustom {
            let isSelected = currentFolder?.folderID == folder.folderID
            let title = isSelected ? "✓ \(folder.name)" : folder.name
            alertController.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectCustomFolder(folder)
            })
        }

        alertController.addAction(UIAlertAction(
            title: LocalizedString("private-message-folder.manage"),
            style: .default
        ) { [weak self] _ in
            guard let self = self else { return }
            self.restorePreviousSelection()
            self.delegate?.folderPickerDidRequestManageFolders(self)
        })

        alertController.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel) { [weak self] _ in
            self?.restorePreviousSelection()
        })

        if let popover = alertController.popoverPresentationController {
            popover.sourceView = segmentedControl
            let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
            popover.sourceRect = CGRect(x: segmentWidth * 2, y: 0, width: segmentWidth, height: segmentedControl.bounds.height)
            popover.permittedArrowDirections = [.up]
            popover.delegate = self
        }

        viewController.present(alertController, animated: true)
    }

    private func restorePreviousSelection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let current = self.currentFolder {
                switch current.folderID {
                case "0":
                    self.segmentedControl.selectedSegmentIndex = 0
                case "-1":
                    self.segmentedControl.selectedSegmentIndex = 1
                default:
                    // Custom folder - keep segment 2 selected (shows folder name)
                    self.segmentedControl.selectedSegmentIndex = 2
                }
            }
        }
    }

    func updateFolders(_ folders: [PrivateMessageFolder]) {
        self.allFolders = folders

        if let current = currentFolder {
            if folders.contains(where: { $0.folderID == current.folderID }) {
                selectFolder(current)
            } else {
                // Current folder was deleted — fall back to the inbox and reset segment 2's title.
                if segmentedControl.selectedSegmentIndex == 2 {
                    segmentedControl.setTitle(LocalizedString("private-message-folder.more"), forSegmentAt: 2)
                }
                if let inbox = folders.first(where: { $0.folderID == "0" }) {
                    selectFolder(inbox)
                    delegate?.folderPicker(self, didSelectFolder: inbox)
                }
            }
        }

        // If no custom folders remain, reset segment 2 back to the default "Folders" label.
        let hasCustomFolders = folders.contains { $0.isCustom }
        if !hasCustomFolders, segmentedControl.numberOfSegments == 3,
           let currentTitle = segmentedControl.titleForSegment(at: 2),
           currentTitle != LocalizedString("private-message-folder.more") {
            segmentedControl.setTitle(LocalizedString("private-message-folder.more"), forSegmentAt: 2)
        }
    }

    func selectFolder(_ folder: PrivateMessageFolder) {
        currentFolder = folder

        switch folder.folderID {
        case "0":
            segmentedControl.selectedSegmentIndex = 0
        case "-1":
            segmentedControl.selectedSegmentIndex = 1
        default:
            if segmentedControl.numberOfSegments == 3 {
                let customTitle = folder.name
                segmentedControl.setTitle(customTitle, forSegmentAt: 2)
                segmentedControl.selectedSegmentIndex = 2
            }
        }
    }

    private func selectCustomFolder(_ folder: PrivateMessageFolder) {
        currentFolder = folder
        segmentedControl.setTitle(folder.name, forSegmentAt: 2)
        segmentedControl.selectedSegmentIndex = 2
        delegate?.folderPicker(self, didSelectFolder: folder)
    }

    func applyTheme(_ theme: Theme) {
        segmentedControl.backgroundColor = theme[uicolor: "ratingIconEmptyColor"]
        segmentedControl.selectedSegmentTintColor = theme[uicolor: "tintColor"]

        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        ]
        segmentedControl.setTitleTextAttributes(normalTextAttributes, for: .normal)

        let selectedTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        ]
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }

    @objc private func handleSegmentTap(_ gesture: UITapGestureRecognizer) {
        // The gesture delegate has already filtered taps to segment 2.
        if segmentedControl.selectedSegmentIndex == 2 {
            showFoldersMenu()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MessageFolderPickerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard segmentedControl.selectedSegmentIndex == 2 else { return false }

        // apportionsSegmentWidthsByContent gives variable widths, so locate the tap by summing segment 0 & 1.
        let location = touch.location(in: segmentedControl)
        let width0 = segmentedControl.widthForSegment(at: 0)
        let width1 = segmentedControl.widthForSegment(at: 1)

        if width0 == 0 || width1 == 0 {
            let segmentWidth = segmentedControl.bounds.width / 3.0
            return location.x >= segmentWidth * 2
        }
        return location.x >= width0 + width1
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

extension MessageFolderPickerView: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        restorePreviousSelection()
    }
}
