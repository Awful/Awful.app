//  MessageListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageListViewController")

// MARK: - Layout Constants
private enum LayoutConstants {
    static let folderPickerHeight: CGFloat = 39
    static let editToolbarHeight: CGFloat = 44
    static let toolbarLeadingSpace: CGFloat = 8
    static let toolbarTrailingSpace: CGFloat = 55  // Aligns delete button with Settings tab
}

// MARK: - UserDefaults Keys
private enum UserDefaultsKey {
    static let lastFolderID = "MessageListLastFolderID"
}

@objc(MessageListViewController)
final class MessageListViewController: TableViewController {

    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    private var dataSource: MessageListDataSource?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    private var unreadMessageCountObserver: ManagedObjectCountObserver!
    private var folderPicker: MessageFolderPickerView?
    private var folderPickerContainer: UIView?
    private var currentFolder: PrivateMessageFolder?
    private var allFolders: [PrivateMessageFolder] = []
    private var editToolbar: UIToolbar?
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
        
        title = LocalizedString("private-message-tab.title")
        
        tabBarItem.accessibilityLabel = LocalizedString("private-message-tab.accessibility-label")
        tabBarItem.image = UIImage(named: "pm-icon")
        tabBarItem.selectedImage = UIImage(named: "pm-icon-filled")
        
        let updateBadgeValue = { [weak self] (unreadCount: Int) -> Void in
            self?.tabBarItem?.badgeValue = unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }
        unreadMessageCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: PrivateMessage.entityName,
            predicate: NSPredicate(format: "%K == NO", #keyPath(PrivateMessage.seen)),
            didChange: updateBadgeValue)
        updateBadgeValue(unreadMessageCountObserver.count)
        
        navigationItem.leftBarButtonItem = editButtonItem
        let composeItem = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(MessageListViewController.didTapComposeButtonItem(_:)))
        composeItem.accessibilityLabel = LocalizedString("private-message-list.compose-button.accessibility-label")
        navigationItem.rightBarButtonItem = composeItem
        
        themeDidChange()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeDataSource() -> MessageListDataSource {
        let dataSource = try! MessageListDataSource(
            managedObjectContext: managedObjectContext,
            tableView: tableView,
            folder: currentFolder)
        dataSource.deletionDelegate = self
        return dataSource
    }
    
    private var composeViewController: MessageComposeViewController?
    
    @objc private func didTapComposeButtonItem(_ sender: UIBarButtonItem) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if composeViewController == nil {
            let compose = MessageComposeViewController()
            compose.restorationIdentifier = "New message"
            compose.delegate = self
            composeViewController = compose
        }

        if let compose = composeViewController {
            present(compose.enclosingNavigationController, animated: true, completion: nil)
        }
    }
    
    private func refreshIfNecessary() {
        if !canSendPrivateMessages { return }

        if tableView.numberOfSections >= 1, tableView.numberOfRows(inSection: 0) == 0 {
            return refresh()
        }
        
        if RefreshMinder.sharedMinder.shouldRefresh(.privateMessagesInbox) {
            return refresh()
        }
    }
    
    @objc private func refresh() {
        startAnimatingPullToRefresh()

        Task {
            do {
                let folderID = currentFolder?.folderID ?? "0"
                _ = try await ForumsClient.shared.listPrivateMessagesInFolder(folderID: folderID)

                if folderID == "0" {
                    RefreshMinder.sharedMinder.didRefresh(.privateMessagesInbox)
                }

                await loadFolders()
            } catch {
                if visible {
                    let alert = UIAlertController(networkError: error)
                    present(alert, animated: true)
                }
            }
            stopAnimatingPullToRefresh()
        }
    }

    private func loadFolders() async {
        do {
            let folders = try await ForumsClient.shared.listPrivateMessageFolders()
            await MainActor.run {
                self.allFolders = folders
                self.folderPicker?.updateFolders(folders)

                // Check if current folder still exists, otherwise switch to inbox
                if let current = currentFolder {
                    if !folders.contains(where: { $0.folderID == current.folderID }) {
                        // Current folder was deleted, switch to inbox
                        if let inbox = folders.first(where: { $0.folderID == "0" }) {
                            setCurrentFolder(inbox)
                        }
                    }
                } else if currentFolder == nil, let inbox = folders.first(where: { $0.folderID == "0" }) {
                    setCurrentFolder(inbox)
                }
            }
        } catch {
            logger.error("Failed to load folders: \(error)")
        }
    }

    private func setCurrentFolder(_ folder: PrivateMessageFolder) {
        guard folder.folderID != currentFolder?.folderID else { return }
        currentFolder = folder
        folderPicker?.selectFolder(folder)

        dataSource = makeDataSource()
        tableView.reloadData()

        UserDefaults.standard.set(folder.folderID, forKey: UserDefaultsKey.lastFolderID)
    }
    
    func showMessage(_ message: PrivateMessage) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let viewController = MessageViewController(privateMessage: message)
        viewController.restorationIdentifier = "Message"
        showDetailViewController(viewController, sender: self)
    }

    private func deleteMessage(_ message: PrivateMessage) {
        guard let context = message.managedObjectContext else { return }

        logger.debug("deleting")
        context.delete(message)

        Task {
            do {
                try await ForumsClient.shared.deletePrivateMessage(message)
            } catch {
                if visible {
                    let alert = UIAlertController(title: LocalizedString("private-messages-list.deletion-error.title"), error: error)
                    present(alert, animated: true)
                }
            }
        }
    }

    private func showFolderPicker(for message: PrivateMessage) {
        let alert = UIAlertController(
            title: LocalizedString("private-messages-list.move-folder.title"),
            message: LocalizedString("private-messages-list.move-folder.message"),
            preferredStyle: .actionSheet
        )

        // Add folder options, excluding the current folder
        for folder in allFolders where folder.folderID != currentFolder?.folderID {
            alert.addAction(UIAlertAction(title: displayName(for: folder), style: .default) { [weak self] _ in
                self?.moveMessage(message, to: folder)
            })
        }

        alert.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel))

        // Configure for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            if let indexPath = dataSource?.indexPath(for: message) {
                popover.sourceRect = tableView.rectForRow(at: indexPath)
            }
        }

        present(alert, animated: true)
    }

    private func moveMessage(_ message: PrivateMessage, to folder: PrivateMessageFolder) {
        Task {
            do {
                try await ForumsClient.shared.movePrivateMessage(message, toFolderID: folder.folderID)
                // The message will automatically disappear from the current folder view
                // due to the NSFetchedResultsController detecting the folder change
            } catch {
                if visible {
                    let alert = UIAlertController(
                        title: LocalizedString("private-messages-list.move-error.title"),
                        error: error
                    )
                    present(alert, animated: true)
                }
            }
        }
    }

    private func displayName(for folder: PrivateMessageFolder) -> String {
        switch folder.folderID {
        case "0":
            return LocalizedString("private-message-folder.inbox")
        case "-1":
            return LocalizedString("private-message-folder.sent")
        default:
            return folder.name
        }
    }

    private func recalculateSeparatorInset() {
        tableView.separatorInset.left = MessageListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }

    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup folder picker first, before table view configuration
        setupFolderPicker()

        tableView.estimatedRowHeight = 65
        recalculateSeparatorInset()

        loadInitialFolder()

        dataSource = makeDataSource()
        tableView.reloadData()

        pullToRefreshBlock = { [unowned self] in
            self.refresh()
        }
    }

    private func setupFolderPicker() {
        // Create a container view for the fixed header
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.isUserInteractionEnabled = true

        headerView.backgroundColor = .clear

        let picker = MessageFolderPickerView()
        picker.delegate = self

        picker.applyTheme(theme)

        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.isUserInteractionEnabled = true
        folderPicker = picker

        headerView.addSubview(picker)
        folderPickerContainer = headerView

        // Add header view to the table view's parent (which is the root view for UITableViewController)
        // We need to add it after the table view is loaded
        view.addSubview(headerView)
        // Bring header to front so it appears above the table view
        view.bringSubviewToFront(headerView)

        NSLayoutConstraint.activate([
            // Header view constraints - fixed at top
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: LayoutConstants.folderPickerHeight),

            // Picker constraints
            picker.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            picker.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        // Adjust table view content to be below the header
        // Don't use constraints on the table view itself since it's managed by UITableViewController
        // Keep automatic adjustment for safe area but add our header height
        tableView.contentInset.top = LayoutConstants.folderPickerHeight
        tableView.verticalScrollIndicatorInsets.top = LayoutConstants.folderPickerHeight

        // Scroll to top to ensure content starts at the right position
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.contentInset.top), animated: false)
    }


    private func loadInitialFolder() {
        let lastFolderID = UserDefaults.standard.string(forKey: UserDefaultsKey.lastFolderID) ?? "0"

        Task {
            await loadFolders()
            if let folder = allFolders.first(where: { $0.folderID == lastFolderID }) {
                await MainActor.run {
                    setCurrentFolder(folder)
                }
            }
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        // Takes care of toggling the button's title.
        super.setEditing(editing, animated: true)

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Toggle table view editing.
        tableView.setEditing(editing, animated: true)

        // Enable multiple selection in edit mode for bulk operations
        tableView.allowsMultipleSelectionDuringEditing = editing

        // Show/hide toolbar with actions when in edit mode
        if editing {
            showEditToolbar()
        } else {
            hideEditToolbar()
        }
    }

    private func showEditToolbar() {
        // Remove any existing toolbar first
        editToolbar?.removeFromSuperview()

        // Create custom toolbar
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let leftSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        leftSpace.width = LayoutConstants.toolbarLeadingSpace

        let moveButton = UIBarButtonItem(
            title: LocalizedString("table-view.action.move"),
            style: .plain,
            target: self,
            action: #selector(moveSelectedMessages)
        )

        let deleteButton = UIBarButtonItem(
            title: LocalizedString("table-view.action.delete"),
            style: .plain,
            target: self,
            action: #selector(deleteSelectedMessages)
        )
        deleteButton.tintColor = .systemRed

        let rightSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        rightSpace.width = LayoutConstants.toolbarTrailingSpace

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [leftSpace, moveButton, flexSpace, deleteButton, rightSpace]

        // Add toolbar to the view hierarchy
        view.addSubview(toolbar)

        // Position toolbar above the tab bar
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        editToolbar = toolbar

        // Adjust table view content inset to make room for toolbar
        var contentInset = tableView.contentInset
        contentInset.bottom = LayoutConstants.editToolbarHeight
        tableView.contentInset = contentInset
        tableView.scrollIndicatorInsets = contentInset
    }

    private func hideEditToolbar() {
        editToolbar?.removeFromSuperview()
        editToolbar = nil

        // Reset table view content inset
        var contentInset = tableView.contentInset
        contentInset.bottom = 0
        tableView.contentInset = contentInset
        tableView.scrollIndicatorInsets = contentInset
    }

    @objc private func moveSelectedMessages() {
        guard let selectedRows = tableView.indexPathsForSelectedRows,
              !selectedRows.isEmpty else {
            let alert = UIAlertController(
                title: LocalizedString("private-messages-list.no-selection.title"),
                message: LocalizedString("private-messages-list.no-selection.message"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: LocalizedString("ok"), style: .default))
            present(alert, animated: true)
            return
        }

        // Show folder picker for selected messages
        showFolderPickerForMultiple(messages: selectedRows)
    }

    @objc private func deleteSelectedMessages() {
        guard let selectedRows = tableView.indexPathsForSelectedRows,
              !selectedRows.isEmpty else {
            let alert = UIAlertController(
                title: LocalizedString("private-messages-list.no-selection.title"),
                message: LocalizedString("private-messages-list.no-selection.message"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: LocalizedString("ok"), style: .default))
            present(alert, animated: true)
            return
        }

        let alert = UIAlertController(
            title: LocalizedString("private-messages-list.delete-confirm.title"),
            message: String(format: LocalizedString("private-messages-list.delete-confirm.message"), selectedRows.count),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LocalizedString("table-view.action.delete"), style: .destructive) { [weak self] _ in
            // Collect messages first to avoid index path invalidation during iteration
            let messages = selectedRows.compactMap { self?.dataSource?.message(at: $0) }
            for message in messages {
                self?.deleteMessage(message)
            }
            self?.setEditing(false, animated: true)
        })

        present(alert, animated: true)
    }

    private func showFolderPickerForMultiple(messages indexPaths: [IndexPath]) {
        let alert = UIAlertController(
            title: LocalizedString("private-messages-list.move-folder.title"),
            message: String(format: LocalizedString("private-messages-list.move-multiple.message"), indexPaths.count),
            preferredStyle: .actionSheet
        )

        // Add folder options, excluding the current folder
        for folder in allFolders where folder.folderID != currentFolder?.folderID {
            alert.addAction(UIAlertAction(title: displayName(for: folder), style: .default) { [weak self] _ in
                // Collect messages first to avoid index path invalidation during iteration
                let messages = indexPaths.compactMap { self?.dataSource?.message(at: $0) }
                for message in messages {
                    self?.moveMessage(message, to: folder)
                }
                self?.setEditing(false, animated: true)
            })
        }

        alert.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel))

        // Configure for iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = toolbarItems?.first
        }

        present(alert, animated: true)
    }
    

    override func themeDidChange() {
        super.themeDidChange()

        composeViewController?.themeDidChange()

        folderPicker?.applyTheme(theme)

        if let headerView = folderPickerContainer {
            headerView.backgroundColor = .clear
        }

        tableView.separatorColor = theme["listSeparatorColor"]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshIfNecessary()
    }
}

// MARK: UITableViewDelegate
extension MessageListViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return dataSource!.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // In edit mode, tapping should select/deselect for bulk operations, not open the message
        if tableView.isEditing {
            // Selection is handled automatically by the table view in edit mode
            return
        }

        let message = dataSource!.message(at: indexPath)
        showMessage(message)
    }

    // Disable swipe actions entirely since they don't work in edit mode
    // and we don't want accidental deletions in normal mode
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        return nil
    }

    // Allow editing for all rows (for the selection circles in edit mode)
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // Return .none to show selection circles instead of delete buttons when multiple selection is enabled
        return .none
    }
}

extension MessageListViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
        if !shouldKeepDraft {
            self.composeViewController = nil
        }
    }
}

extension MessageListViewController {
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(composeViewController, forKey: ComposeViewControllerKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        composeViewController = coder.decodeObject(forKey: ComposeViewControllerKey) as! MessageComposeViewController?
        composeViewController?.delegate = self
    }
}

private let ComposeViewControllerKey = "AwfulComposeViewController"

extension MessageListViewController: MessageListDataSourceDeletionDelegate {
    func didDeleteMessage(_ message: PrivateMessage, in dataSource: MessageListDataSource) {
        deleteMessage(message)
    }
}

extension MessageListViewController: MessageFolderPickerViewDelegate {
    func folderPicker(_ picker: MessageFolderPickerView, didSelectFolder folder: PrivateMessageFolder) {
        setCurrentFolder(folder)
        refresh()
    }

    func folderPickerDidRequestManageFolders(_ picker: MessageFolderPickerView) {
        let manageFoldersVC = MessageFolderManagementViewController(managedObjectContext: managedObjectContext)
        manageFoldersVC.onFoldersChanged = { [weak self] in
            // Reload folders when management view makes changes
            Task {
                await self?.loadFolders()
            }
        }
        let nav = NavigationController(rootViewController: manageFoldersVC)
        present(nav, animated: true)
    }
}
