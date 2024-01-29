//  MessageListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import CoreData
import UIKit

private let Log = Logger.get()

@objc(MessageListViewController)
final class MessageListViewController: TableViewController {

    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    private var dataSource: MessageListDataSource?
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    private let managedObjectContext: NSManagedObjectContext
    @FoilDefaultStorage(Settings.showThreadTags) private var showThreadTags
    private var unreadMessageCountObserver: ManagedObjectCountObserver!
    
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
            tableView: tableView)
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
                _ = try await ForumsClient.shared.listPrivateMessagesInInbox()
                RefreshMinder.sharedMinder.didRefresh(.privateMessagesInbox)
            } catch {
                if visible {
                    let alert = UIAlertController(networkError: error)
                    present(alert, animated: true)
                }
            }
            stopAnimatingPullToRefresh()
        }
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

        Log.d("deleting")
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

    private func recalculateSeparatorInset() {
        tableView.separatorInset.left = MessageListCell.separatorLeftInset(
            showsTagAndRating: showThreadTags,
            inTableWithWidth: tableView.bounds.width
        )
    }

    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 65
        recalculateSeparatorInset()

        dataSource = makeDataSource()
        tableView.reloadData()

        pullToRefreshBlock = { [unowned self] in
            self.refresh()
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
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        composeViewController?.themeDidChange()

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
        let message = dataSource!.message(at: indexPath)
        showMessage(message)
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        if tableView.isEditing {
            let delete = UIContextualAction(style: .destructive, title: LocalizedString("table-view.action.delete"), handler: { action, view, completion in
                guard let message = self.dataSource?.message(at: indexPath) else { return }
                self.deleteMessage(message)
                completion(true)
            })
            let config = UISwipeActionsConfiguration(actions: [delete])
            config.performsFirstActionWithFullSwipe = false
            return config
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
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
