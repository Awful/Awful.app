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

final class MessageFolderManagementViewController: TableViewController {

    private let managedObjectContext: NSManagedObjectContext
    private var folders: [PrivateMessageFolder] = []
    var onFoldersChanged: (() -> Void)?

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .grouped)

        title = LocalizedString("private-message-folder.manage-title")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FolderCell")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )

        // Create both Edit and Add buttons
        let editButton = editButtonItem
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
        navigationItem.rightBarButtonItems = [addButton, editButton]

        loadFolders()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)

        // Reload footer to update text
        if tableView.footerView(forSection: 0) != nil {
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
        }
    }

    private func loadFolders() {
        Task {
            do {
                let allFolders = try await ForumsClient.shared.listPrivateMessageFolders()
                await MainActor.run {
                    self.folders = allFolders.filter { $0.isCustom }
                    self.tableView.reloadData()
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
        // Start with create button disabled
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
        // Limit to max folder name length
        if let text = textField.text, text.count > maxFolderNameLength {
            textField.text = String(text.prefix(maxFolderNameLength))
        }

        // Enable/disable create button based on text length
        if let alertController = presentedViewController as? UIAlertController,
           let text = textField.text,
           !text.isEmpty,
           text.count <= maxFolderNameLength {
            alertController.actions.first?.isEnabled = true
        } else if let alertController = presentedViewController as? UIAlertController {
            alertController.actions.first?.isEnabled = false
        }
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

        // Show confirmation - the server automatically moves messages to inbox when deleting a folder
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
                // The server does NOT automatically move messages when deleting a folder.
                // Messages remain in a "ghost" folder accessible by ID but invisible in the UI.
                // We must manually move each message before deleting the folder.
                let messages = try await ForumsClient.shared.listPrivateMessagesInFolder(folderID: folder.folderID)

                // Get current username to determine if message was sent or received
                let currentUsername = UserDefaults.standard.string(forKey: "username")

                // Move each message: sent messages to Sent folder, received to Inbox
                for message in messages {
                    let wasSentByCurrentUser = message.from?.username == currentUsername
                    let targetFolderID = wasSentByCurrentUser ? "-1" : "0"
                    try await ForumsClient.shared.movePrivateMessage(message, toFolderID: targetFolderID)
                }

                // Now safe to delete the folder
                try await ForumsClient.shared.deletePrivateMessageFolder(folderID: folder.folderID, folderName: folder.name)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.folders.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
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

    override func themeDidChange() {
        super.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
        tableView.backgroundColor = theme["backgroundColor"]
    }
}

// MARK: UITableViewDataSource
extension MessageFolderManagementViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
        let folder = folders[indexPath.row]

        cell.textLabel?.text = folder.name
        cell.textLabel?.textColor = theme[uicolor: "listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]

        let selectedView = UIView()
        selectedView.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedView

        return cell
    }
}

// MARK: UITableViewDelegate
extension MessageFolderManagementViewController {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return LocalizedString("private-message-folder.custom-folders-header")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if tableView.isEditing {
            return LocalizedString("private-message-folder.footer-editing")
        }
        return LocalizedString("private-message-folder.footer-normal")
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = theme[uicolor: "listSecondaryTextColor"]
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let footer = view as? UITableViewHeaderFooterView {
            footer.textLabel?.textColor = theme[uicolor: "listSecondaryTextColor"]
            footer.textLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only allow editing when in edit mode
        return tableView.isEditing
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteFolder(at: indexPath)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        // Disable swipe-to-delete - only allow deletion in edit mode
        return nil
    }
}
