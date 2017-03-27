//  MessageListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

@objc(MessageListViewController)
final class MessageListViewController: TableViewController {
    fileprivate let managedObjectContext: NSManagedObjectContext
    fileprivate var dataSource: MessagesDataSource!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
        
        title = "Private Messages"
        
        tabBarItem.title = "Messages"
        tabBarItem.accessibilityLabel = "Private messages"
        tabBarItem.image = UIImage(named: "pm-icon")
        tabBarItem.selectedImage = UIImage(named: "pm-icon-filled")
        updateUnreadMessageCountBadge()
        
        navigationItem.leftBarButtonItem = editButtonItem
        let composeItem = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(MessageListViewController.didTapComposeButtonItem(_:)))
        composeItem.accessibilityLabel = "Compose"
        navigationItem.rightBarButtonItem = composeItem
        
        let noteCenter = NotificationCenter.default
        noteCenter.addObserver(self, selector: #selector(MessageListViewController.unreadMessageCountDidChange(_:)), name: NSNotification.Name(rawValue: NewMessageChecker.didChangeNotification), object: nil)
        noteCenter.addObserver(self, selector: #selector(MessageListViewController.settingsDidChange(_:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc fileprivate func settingsDidChange(_ note: Notification) {
        if ((note as NSNotification).userInfo?[AwfulSettingsDidChangeSettingKey] as? String)! == AwfulSettingsKeys.showThreadTags.takeUnretainedValue() as String {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }
    
    fileprivate var composeViewController: MessageComposeViewController?
    
    @objc fileprivate func didTapComposeButtonItem(_ sender: UIBarButtonItem) {
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
    
    fileprivate func updateUnreadMessageCountBadge() {
        let unreadCount = NewMessageChecker.sharedChecker.unreadCount
        if unreadCount > 0 {
            tabBarItem.badgeValue = "\(unreadCount)"
        } else {
            tabBarItem.badgeValue = nil
        }
    }
    
    @objc fileprivate func unreadMessageCountDidChange(_ note: Notification) {
        updateUnreadMessageCountBadge()
    }
    
    fileprivate func refreshIfNecessary() {
        if !AwfulSettings.shared().canSendPrivateMessages { return }
        
        if dataSource.numberOfSections >= 1 && dataSource.tableView(tableView, numberOfRowsInSection: 0) == 0 {
            return refresh()
        }
        
        if RefreshMinder.sharedMinder.shouldRefresh(.privateMessagesInbox) {
            return refresh()
        }
    }
    
    @objc fileprivate func refresh() {
        startAnimatingPullToRefresh()
        
        AwfulForumsClient.shared().listPrivateMessageInboxAndThen { [weak self] (error: Error?, messages: [Any]?) in
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                if self?.visible == true {
                    self?.present(alert, animated: true, completion: nil)
                }
            } else {
                RefreshMinder.sharedMinder.didRefresh(.privateMessagesInbox)
            }
            self?.stopAnimatingPullToRefresh()
        }
    }
    
    func showMessage(_ message: PrivateMessage) {
        let viewController = MessageViewController(privateMessage: message)
        viewController.restorationIdentifier = "Message"
        showDetailViewController(viewController, sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 65
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "Message")
        dataSource = MessagesDataSource(managedObjectContext: managedObjectContext)
        dataSource.delegate = self
        dataSource.deletionDelegate = self
        tableView.dataSource = dataSource
        
        pullToRefreshBlock = { [unowned self] in
            self.refresh()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        composeViewController?.themeDidChange()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshIfNecessary()
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        let cell = cell as! MessageCell
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.senderLabel.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.subheadline)
        cell.senderLabel.font = UIFont.boldSystemFont(ofSize: descriptor.pointSize)
        cell.dateLabel.textColor = theme["listTextColor"]
        cell.subjectLabel.textColor = theme["listTextColor"]
        cell.separator.backgroundColor = theme["listSeparatorColor"]
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedBackgroundView
    }
}

extension MessageListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let message = dataSource.itemAtIndexPath(indexPath) as! PrivateMessage
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

private protocol DeletesMessages: class {
    func deleteMessage(_ message: PrivateMessage)
}

extension MessageListViewController: DeletesMessages {
    fileprivate func deleteMessage(_ message: PrivateMessage) {
        message.managedObjectContext!.delete(message)
        if !message.seen {
            NewMessageChecker.sharedChecker.decrementUnreadCount()
        }
        AwfulForumsClient.shared().delete(message) { [weak self] (error: Error?) in
            if let error = error {
                let alert = UIAlertController(title: "Could Not Delete Message", error: error)
                if self?.visible == true {
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

final class MessagesDataSource: FetchedDataSource<PrivateMessage> {
    fileprivate weak var deletionDelegate: DeletesMessages?
    
    init(managedObjectContext: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sentDate", ascending: false)]
        super.init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil)
    }
    
    fileprivate var threadTagObservers = [String: NewThreadTagObserver]()
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = itemAtIndexPath(indexPath) as! PrivateMessage
        let cell = tableView.dequeueReusableCell(withIdentifier: "Message", for: indexPath) as! MessageCell
        
        cell.showsTag = AwfulSettings.shared().showThreadTags
        if cell.showsTag {
            if let imageName = message.threadTag?.imageName {
                if let image = ThreadTagLoader.imageNamed(imageName) {
                    cell.tagImageView.image = image
                } else {
                    cell.tagImageView.image = ThreadTagLoader.emptyPrivateMessageImage
                    
                    let messageID = message.messageID
                    threadTagObservers[messageID] = NewThreadTagObserver(imageName: imageName) { [unowned self] image in
                        if let indexPath = tableView.indexPath(for: cell) {
                            let message = self.itemAtIndexPath(indexPath) as! PrivateMessage
                            if message.messageID == messageID {
                                cell.tagImageView.image = image
                            }
                        }
                        self.threadTagObservers.removeValue(forKey: messageID)
                    }
                }
            } else {
                cell.tagImageView.image = ThreadTagLoader.emptyPrivateMessageImage
            }
        }
        
        if message.replied {
            cell.tagOverlayImageView.image = UIImage(named: "pmreplied.gif")
        } else if message.forwarded {
            cell.tagOverlayImageView.image = UIImage(named: "pmforwarded.gif")
        } else if !message.seen {
            cell.tagOverlayImageView.image = UIImage(named: "newpm.gif")
        } else {
            cell.tagOverlayImageView.image = nil
        }
        
        cell.senderLabel.text = message.fromUsername
        let sentDateString = stringForSentDate(message.sentDate as Date?)
        cell.dateLabel.text = sentDateString
        cell.subjectLabel.text = message.subject
        
        var accessibilityLabel = message.fromUsername ?? ""
        accessibilityLabel += ". " + (message.subject ?? "")
        accessibilityLabel += ". " + sentDateString
        cell.accessibilityLabel = accessibilityLabel
        
        return cell
    }
    
    fileprivate func stringForSentDate(_ date: Date?) -> String {
        if let date = date {
            let calendar = Calendar.current
            let units: NSCalendar.Unit = [.day, .month, .year]
            let components = (calendar as NSCalendar).components(units, from: date)
            let today = (calendar as NSCalendar).components(units, from: Date())
            let formatter = components == today ? timeFormatter : dateFormatter
            return formatter.string(from: date)
        } else {
            return ""
        }
    }
    
    fileprivate lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
        }()
    
    fileprivate lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
        }()
    
    func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: IndexPath) {
        if editingStyle == .delete {
            let message = itemAtIndexPath(indexPath) as! PrivateMessage
            deletionDelegate?.deleteMessage(message)
        }
    }
}
