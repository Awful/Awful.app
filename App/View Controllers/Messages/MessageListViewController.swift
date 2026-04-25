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
final class MessageListViewController: CollectionViewController {

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
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionReusableView>!

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(collectionViewLayout: Self.makeLayout(separatorLeadingInset: 0, separatorColor: nil))

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

        headerRegistration = makeHeaderRegistration()

        themeDidChange()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout(separatorLeadingInset: CGFloat, separatorColor: UIColor?) -> UICollectionViewLayout {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfig.headerMode = .supplementary
        listConfig.headerTopPadding = 8
        listConfig.backgroundColor = .clear

        var separatorConfig = UIListSeparatorConfiguration(listAppearance: .plain)
        separatorConfig.topSeparatorVisibility = .hidden
        separatorConfig.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: separatorLeadingInset, bottom: 0, trailing: 0)
        if let separatorColor {
            separatorConfig.color = separatorColor
        }
        listConfig.separatorConfiguration = separatorConfig

        // Swipe-to-delete is disabled — destructive actions go through edit mode.
        listConfig.trailingSwipeActionsConfigurationProvider = { _ in nil }

        return CollectionViewController.makeListLayout(using: listConfig)
    }

    private func rebuildLayout() {
        let inset = MessageListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: collectionView.bounds.width
        )
        let color = theme[uicolor: "listSeparatorColor"]
        collectionView.setCollectionViewLayout(
            Self.makeLayout(separatorLeadingInset: inset, separatorColor: color),
            animated: false
        )
    }

    private func makeHeaderRegistration() -> UICollectionView.SupplementaryRegistration<UICollectionReusableView> {
        UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, _ in
            guard let self, let picker = self.folderPicker else { return }
            header.backgroundColor = .clear

            if picker.superview !== header {
                picker.removeFromSuperview()
                picker.translatesAutoresizingMaskIntoConstraints = false
                header.addSubview(picker)

                NSLayoutConstraint.activate([
                    picker.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                    picker.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
                    picker.topAnchor.constraint(equalTo: header.topAnchor),
                    picker.bottomAnchor.constraint(equalTo: header.bottomAnchor),
                    picker.heightAnchor.constraint(equalToConstant: LayoutConstants.folderPickerHeight),
                ])
            }
        }
    }

    private func makeDataSource() -> MessageListDataSource {
        let dataSource = try! MessageListDataSource(
            managedObjectContext: managedObjectContext,
            collectionView: collectionView,
            folder: currentFolder,
            supplementaryViewProvider: { [weak self] collectionView, kind, indexPath in
                guard let self, kind == UICollectionView.elementKindSectionHeader else { return nil }
                return collectionView.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            }
        )
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

        if collectionView.numberOfSections >= 1, collectionView.numberOfItems(inSection: 0) == 0 {
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
        collectionView.reloadData()

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
            popover.sourceView = collectionView
            if let indexPath = dataSource?.indexPath(for: message) {
                popover.sourceRect = collectionView.layoutAttributesForItem(at: indexPath)?.frame ?? .zero
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

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupFolderPicker()

        rebuildLayout()

        loadInitialFolder()

        dataSource = makeDataSource()
        collectionView.reloadData()

        pullToRefreshBlock = { [unowned self] in
            self.refresh()
        }
    }

    private func setupFolderPicker() {
        let picker = MessageFolderPickerView()
        picker.delegate = self
        picker.applyTheme(theme)
        folderPicker = picker
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

        collectionView.isEditing = editing
        collectionView.allowsMultipleSelectionDuringEditing = editing

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
        // collectionView in a UICollectionViewController), since autolayout subviews of a UIScrollView
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

        var contentInset = collectionView.contentInset
        contentInset.bottom = editToolbarHeight
        collectionView.contentInset = contentInset
        collectionView.verticalScrollIndicatorInsets = contentInset
    }

    private func hideEditToolbar() {
        editToolbar?.removeFromSuperview()
        editToolbar = nil
        editToolbarMoveButton = nil

        var contentInset = collectionView.contentInset
        contentInset.bottom = 0
        collectionView.contentInset = contentInset
        collectionView.verticalScrollIndicatorInsets = contentInset
    }

    @objc private func moveSelectedMessages() {
        guard let selectedRows = collectionView.indexPathsForSelectedItems,
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
        guard let selectedRows = collectionView.indexPathsForSelectedItems,
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
                popover.sourceView = collectionView
                popover.sourceRect = CGRect(x: collectionView.bounds.midX, y: collectionView.bounds.midY, width: 0, height: 0)
            }
        }

        present(alert, animated: true)
    }

    override func themeDidChange() {
        // Rebuild the layout before super reloads so the new separator color and
        // inset are in effect when cells are reconfigured.
        if isViewLoaded {
            rebuildLayout()
        }

        super.themeDidChange()

        composeViewController?.themeDidChange()
        folderPicker?.applyTheme(theme)
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

// MARK: UICollectionViewDelegate
extension MessageListViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // In edit mode the tap is a selection toggle, not a navigation action.
        if collectionView.isEditing { return }

        guard let dataSource else { return }
        let message = dataSource.message(at: indexPath)
        showMessage(message)
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
