//  MessageFolderManagementViewController.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import AwfulCore
import AwfulTheming
import CoreData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageFolderManagement")

// Maximum folder name length allowed by the forums
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
        logger.info("[FOLDER_MGT] Loading folders list")
        Task {
            do {
                let allFolders = try await ForumsClient.shared.listPrivateMessageFolders()
                logger.info("[FOLDER_MGT] Loaded \(allFolders.count) total folders")
                await MainActor.run {
                    self.folders = allFolders.filter { $0.isCustom }
                    logger.info("[FOLDER_MGT] Filtered to \(self.folders.count) custom folders")
                    for folder in self.folders {
                        logger.debug("[FOLDER_MGT]   - Folder: '\(folder.name)' (ID: \(folder.folderID))")
                    }
                    self.tableView.reloadData()
                }
            } catch {
                logger.error("[FOLDER_MGT] Failed to load folders: \(error)")
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
        logger.info("[FOLDER_MGT] Creating folder with name: '\(name)'")
        Task {
            do {
                logger.info("[FOLDER_MGT] Calling API to create folder: '\(name)'")
                try await ForumsClient.shared.createPrivateMessageFolder(name: name)
                logger.info("[FOLDER_MGT] Successfully created folder: '\(name)'")
                loadFolders()
                await MainActor.run { [weak self] in
                    self?.onFoldersChanged?()
                }
            } catch {
                logger.error("[FOLDER_MGT] Failed to create folder '\(name)': \(error)")
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
        logger.info("[FOLDER_MGT] Deleting folder: '\(folder.name)' with ID: '\(folder.folderID)'")

        Task {
            do {
                // First, move all messages in this folder to inbox or sent
                logger.info("[FOLDER_MGT] Moving messages from folder '\(folder.name)' before deletion")

                // Fetch all messages in this folder
                let messages = try await ForumsClient.shared.listPrivateMessagesInFolder(folderID: folder.folderID)
                logger.info("[FOLDER_MGT] Found \(messages.count) messages to move")

                // Get current username to determine sent messages
                let currentUsername = UserDefaults.standard.string(forKey: "com.awfulapp.Awful.username")

                // Move each message to the appropriate folder
                for message in messages {
                    // Check if message was sent by the current user
                    let wasSentByCurrentUser = message.from?.username == currentUsername
                    let targetFolderID = wasSentByCurrentUser ? "-1" : "0"  // -1 for sent, 0 for inbox
                    logger.info("[FOLDER_MGT] Moving message '\(message.subject ?? "")' from '\(message.from?.username ?? "unknown")' to \(wasSentByCurrentUser ? "sent" : "inbox")")
                    try await ForumsClient.shared.movePrivateMessage(message, toFolderID: targetFolderID)
                }

                logger.info("[FOLDER_MGT] All messages moved. Now deleting folder ID: '\(folder.folderID)'")
                try await ForumsClient.shared.deletePrivateMessageFolder(folderID: folder.folderID)
                logger.info("[FOLDER_MGT] Successfully deleted folder: '\(folder.name)'")
                await MainActor.run { [weak self] in
                    self?.folders.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self?.onFoldersChanged?()
                }
            } catch {
                logger.error("[FOLDER_MGT] Failed to delete folder '\(folder.name)' (ID: \(folder.folderID)): \(error)")
                await MainActor.run {
                    let alert = UIAlertController(
                        title: LocalizedString("private-message-folder.delete-error-title"),
                        error: error
                    )
                    present(alert, animated: true)
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
