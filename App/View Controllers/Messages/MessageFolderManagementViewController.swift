//  MessageFolderManagementViewController.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import AwfulCore
import AwfulTheming
import CoreData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageFolderManagement")

/// Maximum folder name length allowed by the SA Forums API
private let maxFolderNameLength = 25

final class MessageFolderManagementViewController: CollectionViewController {

    private let managedObjectContext: NSManagedObjectContext
    private var folders: [PrivateMessageFolder] = []
    var onFoldersChanged: (() -> Void)?

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(collectionViewLayout: Self.makeLayout())

        title = LocalizedString("private-message-folder.manage-title")

        cellRegistration = makeCellRegistration()
        headerRegistration = makeHeaderRegistration()
        footerRegistration = makeFooterRegistration()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .grouped)
        config.headerMode = .supplementary
        config.footerMode = .supplementary
        config.backgroundColor = .clear
        return CollectionViewController.makeListLayout(using: config)
    }

    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, PrivateMessageFolder>!
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    private func makeCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, PrivateMessageFolder> {
        UICollectionView.CellRegistration<UICollectionViewListCell, PrivateMessageFolder> { [weak self] cell, indexPath, folder in
            guard let self else { return }

            var content = cell.defaultContentConfiguration()
            content.text = folder.name
            content.textProperties.color = self.theme[uicolor: "listTextColor"] ?? .label
            cell.contentConfiguration = content

            var background = UIBackgroundConfiguration.clear()
            background.backgroundColor = self.theme["listBackgroundColor"]
            cell.backgroundConfiguration = background

            cell.selectedBackgroundColor = self.theme["listSelectedBackgroundColor"]

            cell.accessories = [
                .delete(displayed: .whenEditing, actionHandler: { [weak self, weak cell] in
                    guard let self,
                          let cell,
                          let currentIndexPath = self.collectionView.indexPath(for: cell)
                    else { return }
                    self.deleteFolder(at: currentIndexPath)
                })
            ]
        }
    }

    private func makeHeaderRegistration() -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell> {
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, _ in
            guard let self else { return }
            var content = header.defaultContentConfiguration()
            content.text = LocalizedString("private-message-folder.custom-folders-header")
            content.textProperties.color = self.theme[uicolor: "listSecondaryTextColor"] ?? .secondaryLabel
            header.contentConfiguration = content
        }
    }

    private func makeFooterRegistration() -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell> {
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { [weak self] footer, _, _ in
            guard let self else { return }
            var content = footer.defaultContentConfiguration()
            content.text = self.isEditing
                ? LocalizedString("private-message-folder.footer-editing")
                : LocalizedString("private-message-folder.footer-normal")
            content.textProperties.color = self.theme[uicolor: "listSecondaryTextColor"] ?? .secondaryLabel
            content.textProperties.font = UIFont.preferredFont(forTextStyle: .footnote)
            footer.contentConfiguration = content
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )

        addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
        updateNavigationItems()

        loadFolders()
    }

    private var addButton: UIBarButtonItem!

    private func updateNavigationItems() {
        // Edit only makes sense when there's something to delete.
        navigationItem.rightBarButtonItems = folders.isEmpty ? [addButton] : [addButton, editButtonItem]
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = editing

        // Footer copy differs between normal and edit mode; reload the section
        // so the supplementary footer re-renders with the new text.
        collectionView.reloadSections(IndexSet(integer: 0))
    }

    private func loadFolders() {
        Task {
            do {
                let allFolders = try await ForumsClient.shared.listPrivateMessageFolders()
                await MainActor.run {
                    self.folders = allFolders.filter { $0.isCustom }
                    self.collectionView.reloadData()
                    self.updateNavigationItems()
                    if self.folders.isEmpty, self.isEditing {
                        self.setEditing(false, animated: true)
                    }
                }
            } catch {
                logger.error("Failed to load folders: \(error)")
                await MainActor.run {
                    let alert = UIAlertController(networkError: error)
                    present(alert, animated: true)
                }
            }
        }
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }

    @objc private func addButtonTapped() {
        let alert = UIAlertController(
            title: LocalizedString("private-message-folder.add-title"),
            message: LocalizedString("private-message-folder.add-message"),
            preferredStyle: .alert
        )

        alert.addTextField { [weak self] textField in
            textField.placeholder = LocalizedString("private-message-folder.name-placeholder")
            textField.autocapitalizationType = .none
            textField.addTarget(self, action: #selector(self?.textFieldDidChange(_:)), for: .editingChanged)
        }

        let createAction = UIAlertAction(
            title: LocalizedString("private-message-folder.create"),
            style: .default
        ) { [weak self] _ in
            guard let folderName = alert.textFields?.first?.text,
                  !folderName.isEmpty,
                  folderName.count <= maxFolderNameLength else { return }
            self?.createFolder(name: folderName)
        }
        createAction.isEnabled = false

        let cancelAction = UIAlertAction(
            title: LocalizedString("cancel"),
            style: .cancel
        )

        alert.addAction(createAction)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text, text.count > maxFolderNameLength {
            textField.text = String(text.prefix(maxFolderNameLength))
        }

        guard let alertController = presentedViewController as? UIAlertController else { return }
        let text = textField.text ?? ""
        alertController.actions.first?.isEnabled = !text.isEmpty && text.count <= maxFolderNameLength
    }

    private func createFolder(name: String) {
        Task {
            do {
                try await ForumsClient.shared.createPrivateMessageFolder(name: name)
                loadFolders()
                await MainActor.run { [weak self] in
                    self?.onFoldersChanged?()
                }
            } catch {
                logger.error("Failed to create folder '\(name)': \(error)")
                await MainActor.run {
                    let alert = UIAlertController(
                        title: LocalizedString("private-message-folder.create-error-title"),
                        error: error
                    )
                    present(alert, animated: true)
                }
            }
        }
    }

    private func deleteFolder(at indexPath: IndexPath) {
        let folder = folders[indexPath.row]

        let alert = UIAlertController(
            title: LocalizedString("private-message-folder.delete-confirm-title"),
            message: LocalizedString("private-message-folder.delete-confirm-message"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel))

        alert.addAction(UIAlertAction(
            title: LocalizedString("private-message-folder.delete-button"),
            style: .destructive
        ) { [weak self] _ in
            self?.performFolderDeletion(folder: folder, at: indexPath)
        })

        present(alert, animated: true)
    }

    private func performFolderDeletion(folder: PrivateMessageFolder, at indexPath: IndexPath) {
        Task {
            do {
                // The server does NOT automatically move messages when deleting a folder;
                // they remain in a ghost folder accessible by ID but invisible in the UI.
                // Manually move each message out before deleting the folder itself.
                let messages = try await ForumsClient.shared.listPrivateMessagesInFolder(folderID: folder.folderID)

                let currentUsername = UserDefaults.standard.string(forKey: "username")

                for message in messages {
                    let wasSentByCurrentUser = message.from?.username == currentUsername
                    let targetFolderID = wasSentByCurrentUser ? "-1" : "0"
                    try await ForumsClient.shared.movePrivateMessage(message, toFolderID: targetFolderID)
                }

                try await ForumsClient.shared.deletePrivateMessageFolder(folderID: folder.folderID, folderName: folder.name)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.folders.remove(at: indexPath.row)
                    self.collectionView.deleteItems(at: [indexPath])
                    self.updateNavigationItems()
                    if self.folders.isEmpty, self.isEditing {
                        self.setEditing(false, animated: true)
                    }
                    self.onFoldersChanged?()
                }
            } catch {
                logger.error("Failed to delete folder '\(folder.name)': \(error)")
                await MainActor.run { [weak self] in
                    let alert = UIAlertController(
                        title: LocalizedString("private-message-folder.delete-error-title"),
                        error: error
                    )
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: UICollectionViewDataSource
extension MessageFolderManagementViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return folders.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: folders[indexPath.row])
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        case UICollectionView.elementKindSectionFooter:
            return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
        default:
            fatalError("unexpected supplementary kind: \(kind)")
        }
    }
}
