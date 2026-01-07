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
    private var customFolders: [PrivateMessageFolder] = []
    private var currentFolder: PrivateMessageFolder?
    private var showingFoldersMenu = false

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

        // Add touch handler for detecting taps on already-selected segment
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSegmentTap(_:)))
        tapGesture.delegate = self
        segmentedControl.addGestureRecognizer(tapGesture)

        // Set proportional segment widths to fit properly
        segmentedControl.apportionsSegmentWidthsByContent = true

        // Make container transparent
        self.backgroundColor = .clear
        self.isOpaque = false

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
            if let folder = customFolders.first(where: { $0.folderID == "0" }) {
                currentFolder = folder
                delegate?.folderPicker(self, didSelectFolder: folder)
            }
        case 1:
            if let folder = customFolders.first(where: { $0.folderID == "-1" }) {
                currentFolder = folder
                delegate?.folderPicker(self, didSelectFolder: folder)
            }
        case 2:
            // Check if a custom folder is already set (segment shows folder name, not "Folders")
            let segmentTitle = segmentedControl.titleForSegment(at: 2) ?? ""
            let defaultTitle = LocalizedString("private-message-folder.more")

            if segmentTitle == defaultTitle {
                // No folder selected, show menu
                showFoldersMenu()
            } else {
                // A custom folder name is shown - find and load it
                if let customFolder = customFolders.first(where: { $0.name == segmentTitle && $0.isCustom }) {
                    currentFolder = customFolder
                    delegate?.folderPicker(self, didSelectFolder: customFolder)
                } else {
                    // Can't find the folder, show menu as fallback
                    showFoldersMenu()
                }
            }
        default:
            break
        }
    }

    private func showFoldersMenu() {
        // Find the view controller to present from
        guard let viewController = self.findViewController() else {
            restorePreviousSelection()
            return
        }

        // Create an alert controller with the menu items
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Apply theme appearance
        let menuAppearance = Theme.defaultTheme()[string: "menuAppearance"]
        alertController.overrideUserInterfaceStyle = menuAppearance == "light" ? .light : .dark

        // Get custom folders
        let customFoldersList = customFolders.filter({ $0.isCustom })

        // If there are no custom folders, only show the manage option
        if !customFoldersList.isEmpty {
            // Add custom folder actions
            for folder in customFoldersList {
                let isSelected = currentFolder?.folderID == folder.folderID
                let title = isSelected ? "✓ \(folder.name)" : folder.name
                alertController.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.selectCustomFolder(folder)
                })
            }
        }

        // Add manage folders option
        alertController.addAction(UIAlertAction(
            title: LocalizedString("private-message-folder.manage"),
            style: .default
        ) { [weak self] _ in
            guard let self = self else { return }
            self.restorePreviousSelection()
            self.delegate?.folderPickerDidRequestManageFolders(self)
        })

        // Add cancel action - restore selection when cancelled
        alertController.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel) { [weak self] _ in
            self?.restorePreviousSelection()
        })

        // Configure for iPad - position from the Folders segment
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = segmentedControl
            // Calculate the rect for the third segment (index 2)
            let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
            let thirdSegmentRect = CGRect(x: segmentWidth * 2, y: 0, width: segmentWidth, height: segmentedControl.bounds.height)
            popover.sourceRect = thirdSegmentRect
            popover.permittedArrowDirections = [.up]

            // Add delegate to handle dismissal
            popover.delegate = self
        }

        // Present without restoring in completion - let user action or dismissal handle it
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
                    self.segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
                }
            }
        }
    }

    func updateFolders(_ folders: [PrivateMessageFolder]) {
        self.customFolders = folders

        // Check current folder still exists, otherwise switch to inbox
        if let current = currentFolder {
            // Check if the current folder still exists
            if folders.contains(where: { $0.folderID == current.folderID }) {
                selectFolder(current)
            } else {
                // Current folder was deleted, switch to inbox and reset third segment title
                if segmentedControl.selectedSegmentIndex == 2 {
                    segmentedControl.setTitle(LocalizedString("private-message-folder.more"), forSegmentAt: 2)
                }
                if let inbox = folders.first(where: { $0.folderID == "0" }) {
                    selectFolder(inbox)
                    delegate?.folderPicker(self, didSelectFolder: inbox)
                }
            }
        } else if let current = currentFolder {
            selectFolder(current)
        }

        // If there are no custom folders and the third segment shows a custom folder name,
        // reset it to "Folders"
        let hasCustomFolders = folders.contains { $0.isCustom }
        if !hasCustomFolders && segmentedControl.numberOfSegments == 3 {
            // Only reset if it's not already showing "Folders"
            if let currentTitle = segmentedControl.titleForSegment(at: 2),
               currentTitle != LocalizedString("private-message-folder.more") {
                segmentedControl.setTitle(LocalizedString("private-message-folder.more"), forSegmentAt: 2)
            }
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
        // Just show the folder name when it's selected
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
        let location = gesture.location(in: segmentedControl)
        let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
        let tappedSegment = Int(location.x / segmentWidth)

        // If tapping the third segment (Folders) and it's already selected, show menu
        if tappedSegment == 2 && segmentedControl.selectedSegmentIndex == 2 {
            showFoldersMenu()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MessageFolderPickerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle the gesture if it's on the third segment and it's already selected
        let location = touch.location(in: segmentedControl)
        let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
        let tappedSegment = Int(location.x / segmentWidth)

        // Only intercept if tapping the already-selected third segment
        // (regardless of whether it shows "Folders" or a folder name)
        return tappedSegment == 2 && segmentedControl.selectedSegmentIndex == 2
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
