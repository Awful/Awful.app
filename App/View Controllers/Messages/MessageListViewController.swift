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

                let currentFolderRemoved = currentFolder.map { c in !folders.contains(where: { $0.folderID == c.folderID }) } ?? true
                if currentFolderRemoved, let inbox = folders.first(where: { $0.folderID == "0" }) {
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
    
    func showMessage(_ message: PrivateMessage, pendingRestoration: PendingMessageRestoration? = nil) {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let viewController = MessageViewController(privateMessage: message)
        if let pending = pendingRestoration {
            viewController.prepareForRestoration(scrollFraction: pending.scrollFraction)
        }
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
        let alert = buildFolderPickerAlert(
            message: LocalizedString("private-messages-list.move-folder.message")
        ) { [weak self] folder in
            self?.moveMessage(message, to: folder)
        }

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            if let indexPath = dataSource?.indexPath(for: message) {
                popover.sourceRect = tableView.rectForRow(at: indexPath)
            }
        }

        present(alert, animated: true)
    }

    private func buildFolderPickerAlert(
        message: String,
        onFolderSelected: @escaping (PrivateMessageFolder) -> Void
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: LocalizedString("private-messages-list.move-folder.title"),
            message: message,
            preferredStyle: .actionSheet
        )

        for folder in allFolders where folder.folderID != currentFolder?.folderID {
            alert.addAction(UIAlertAction(title: displayName(for: folder), style: .default) { _ in
                onFolderSelected(folder)
            })
        }

        alert.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel))

        return alert
    }

    private func moveMessage(_ message: PrivateMessage, to folder: PrivateMessageFolder) {
        Task {
            do {
                try await ForumsClient.shared.movePrivateMessage(message, toFolderID: folder.folderID)
                // The message disappears from the current folder view via the NSFetchedResultsController predicate.
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
        let picker = MessageFolderPickerView()
        picker.delegate = self
        picker.applyTheme(theme)
        picker.translatesAutoresizingMaskIntoConstraints = false
        folderPicker = picker

        // Host the picker in a tableHeaderView so it scrolls with the list and pull-to-refresh
        // uses its natural threshold (a pinned overlay + contentInset.top offsets PullToRefresh's
        // trigger distance).
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: LayoutConstants.folderPickerHeight))
        container.autoresizingMask = .flexibleWidth
        container.backgroundColor = .clear
        container.addSubview(picker)

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            picker.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        tableView.tableHeaderView = container
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
        super.setEditing(editing, animated: true)

        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        tableView.setEditing(editing, animated: true)
        tableView.allowsMultipleSelectionDuringEditing = editing

        if editing {
            showEditToolbar()
        } else {
            hideEditToolbar()
        }
    }

    private var editToolbarMoveButton: UIBarButtonItem?
    private let editToolbarHeight: CGFloat = 44

    private func showEditToolbar() {
        editToolbar?.removeFromSuperview()

        // Host the toolbar on the nav controller's view rather than `view` (which is the
        // tableView in a UITableViewController), since autolayout subviews of a UIScrollView
        // don't receive width constraints reliably.
        guard let host = navigationController?.view else { return }

        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let moveButton = UIBarButtonItem(
            title: LocalizedString("table-view.action.move"),
            style: .plain,
            target: self,
            action: #selector(moveSelectedMessages)
        )
        moveButton.tintColor = theme[uicolor: "tintColor"]
        editToolbarMoveButton = moveButton

        let deleteButton = UIBarButtonItem(
            title: LocalizedString("table-view.action.delete"),
            style: .plain,
            target: self,
            action: #selector(deleteSelectedMessages)
        )
        deleteButton.tintColor = .systemRed

        let flexSpace1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flexSpace2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let flexSpace3 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([flexSpace1, moveButton, flexSpace2, deleteButton, flexSpace3], animated: false)

        host.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: editToolbarHeight),
        ])

        editToolbar = toolbar

        var contentInset = tableView.contentInset
        contentInset.bottom = editToolbarHeight
        tableView.contentInset = contentInset
        tableView.scrollIndicatorInsets = contentInset
    }

    private func hideEditToolbar() {
        editToolbar?.removeFromSuperview()
        editToolbar = nil
        editToolbarMoveButton = nil

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
            // Collect messages up-front since deleting rows invalidates index paths.
            let messages = selectedRows.compactMap { self?.dataSource?.message(at: $0) }
            for message in messages {
                self?.deleteMessage(message)
            }
            self?.setEditing(false, animated: true)
        })

        present(alert, animated: true)
    }

    private func showFolderPickerForMultiple(messages indexPaths: [IndexPath]) {
        let alert = buildFolderPickerAlert(
            message: String(format: LocalizedString("private-messages-list.move-multiple.message"), indexPaths.count)
        ) { [weak self] folder in
            // Collect messages up-front since moves shift index paths.
            let messages = indexPaths.compactMap { self?.dataSource?.message(at: $0) }
            for message in messages {
                self?.moveMessage(message, to: folder)
            }
            self?.setEditing(false, animated: true)
        }

        if let popover = alert.popoverPresentationController {
            if let moveButton = editToolbarMoveButton {
                popover.barButtonItem = moveButton
            } else {
                popover.sourceView = tableView
                popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
            }
        }

        present(alert, animated: true)
    }

    override func themeDidChange() {
        super.themeDidChange()

        composeViewController?.themeDidChange()

        folderPicker?.applyTheme(theme)

        tableView.separatorColor = theme["listSeparatorColor"]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshIfNecessary()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // The toolbar lives on navigationController.view, so leaving edit mode
        // before navigating away prevents it from lingering on other screens.
        if isEditing {
            setEditing(false, animated: false)
        }
    }
}

// MARK: UITableViewDelegate
extension MessageListViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dataSource else { return UITableView.automaticDimension }
        return dataSource.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // In edit mode the tap is a selection toggle, not a navigation action.
        if tableView.isEditing { return }

        guard let dataSource else { return }
        let message = dataSource.message(at: indexPath)
        showMessage(message)
    }

    // Swipe-to-delete is disabled — destructive actions must go through edit mode.
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        return nil
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // .none gives selection circles in edit mode instead of the default delete button.
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
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
            Task { await self?.loadFolders() }
        }
        let nav = NavigationController(rootViewController: manageFoldersVC)
        present(nav, animated: true)
    }
}

extension MessageListViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .messagesList
    }
}
