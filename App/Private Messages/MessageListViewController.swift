//  MessageListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

@objc(MessageListViewController)
final class MessageListViewController: AwfulTableViewController {
    private let managedObjectContext: NSManagedObjectContext
    private var dataSource: MessagesDataSource!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
        
        title = "Private Messages"
        
        tabBarItem.title = "Messages"
        tabBarItem.accessibilityLabel = "Private messages"
        tabBarItem.image = UIImage(named: "pm-icon")
        tabBarItem.selectedImage = UIImage(named: "pm-icon-filled")
        updateUnreadMessageCountBadge()
        
        navigationItem.leftBarButtonItem = editButtonItem()
        let composeItem = UIBarButtonItem(image: UIImage(named: "compose"), style: .Plain, target: self, action: #selector(MessageListViewController.didTapComposeButtonItem(_:)))
        composeItem.accessibilityLabel = "Compose"
        navigationItem.rightBarButtonItem = composeItem
        
        let noteCenter = NSNotificationCenter.defaultCenter()
        noteCenter.addObserver(self, selector: #selector(MessageListViewController.unreadMessageCountDidChange(_:)), name: NewMessageChecker.didChangeNotification, object: nil)
        noteCenter.addObserver(self, selector: #selector(MessageListViewController.settingsDidChange(_:)), name: AwfulSettingsDidChangeNotification, object: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func settingsDidChange(note: NSNotification) {
        if note.userInfo?[AwfulSettingsDidChangeSettingKey] as? String == AwfulSettingsKeys.showThreadTags.takeUnretainedValue() {
            if isViewLoaded() {
                tableView.reloadData()
            }
        }
    }
    
    private var composeViewController: MessageComposeViewController?
    
    @objc private func didTapComposeButtonItem(sender: UIBarButtonItem) {
        if composeViewController == nil {
            let compose = MessageComposeViewController()
            compose.restorationIdentifier = "New message"
            compose.delegate = self
            composeViewController = compose
        }
        if let compose = composeViewController {
            presentViewController(compose.enclosingNavigationController, animated: true, completion: nil)
        }
    }
    
    private func updateUnreadMessageCountBadge() {
        let unreadCount = NewMessageChecker.sharedChecker.unreadCount
        if unreadCount > 0 {
            tabBarItem.badgeValue = "\(unreadCount)"
        } else {
            tabBarItem.badgeValue = nil
        }
    }
    
    @objc private func unreadMessageCountDidChange(note: NSNotification) {
        updateUnreadMessageCountBadge()
    }
    
    private func refreshIfNecessary() {
        if !AwfulSettings.sharedSettings().canSendPrivateMessages { return }
        
        if dataSource.numberOfSections >= 1 && dataSource.tableView(tableView, numberOfRowsInSection: 0) == 0 {
            return refresh()
        }
        
        if RefreshMinder.sharedMinder.shouldRefresh(.PrivateMessagesInbox) {
            return refresh()
        }
    }
    
    @objc private func refresh() {
        refreshControl?.beginRefreshing()
        
        AwfulForumsClient.sharedClient().listPrivateMessageInboxAndThen { [weak self] error, messages in
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                if self?.visible == true {
                    self?.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                RefreshMinder.sharedMinder.didRefresh(.PrivateMessagesInbox)
            }
            self?.refreshControl?.endRefreshing()
        }
    }
    
    func showMessage(message: PrivateMessage) {
        let viewController = MessageViewController(privateMessage: message)
        viewController.restorationIdentifier = "Message"
        showDetailViewController(viewController, sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 65
        tableView.separatorStyle = .None
        tableView.registerNib(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "Message")
        dataSource = MessagesDataSource(managedObjectContext: managedObjectContext)
        dataSource.delegate = self
        dataSource.deletionDelegate = self
        tableView.dataSource = dataSource
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(MessageListViewController.refresh), forControlEvents: .ValueChanged)
        self.refreshControl = refreshControl
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        composeViewController?.themeDidChange()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshIfNecessary()
    }
}

extension MessageListViewController {
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let message = dataSource.itemAtIndexPath(indexPath) as! PrivateMessage
        showMessage(message)
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let cell = cell as! MessageCell
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.senderLabel.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleSubheadline)
        cell.senderLabel.font = UIFont.boldSystemFontOfSize(descriptor.pointSize)
        cell.dateLabel.textColor = theme["listTextColor"]
        cell.subjectLabel.textColor = theme["listTextColor"]
        cell.separator.backgroundColor = theme["listSeparatorColor"]
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedBackgroundView
    }
}

extension MessageListViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismissViewControllerAnimated(true, completion: nil)
        if !shouldKeepDraft {
            self.composeViewController = nil
        }
    }
}

extension MessageListViewController {
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(composeViewController, forKey: ComposeViewControllerKey)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        composeViewController = coder.decodeObjectForKey(ComposeViewControllerKey) as! MessageComposeViewController?
        composeViewController?.delegate = self
    }
}

private let ComposeViewControllerKey = "AwfulComposeViewController"

private protocol DeletesMessages: class {
    func deleteMessage(message: PrivateMessage)
}

extension MessageListViewController: DeletesMessages {
    private func deleteMessage(message: PrivateMessage) {
        message.managedObjectContext!.deleteObject(message)
        if !message.seen {
            NewMessageChecker.sharedChecker.decrementUnreadCount()
        }
        AwfulForumsClient.sharedClient().deletePrivateMessage(message) { [weak self] error in
            if let error = error {
                let alert = UIAlertController(title: "Could Not Delete Message", error: error)
                if self?.visible == true {
                    self?.presentViewController(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

final class MessagesDataSource: FetchedDataSource {
    private weak var deletionDelegate: DeletesMessages?
    
    init(managedObjectContext: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest(entityName: PrivateMessage.entityName())
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sentDate", ascending: false)]
        super.init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil)
    }
    
    private var threadTagObservers = [String: NewThreadTagObserver]()
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let message = itemAtIndexPath(indexPath) as! PrivateMessage
        let cell = tableView.dequeueReusableCellWithIdentifier("Message", forIndexPath: indexPath) as! MessageCell
        
        cell.showsTag = AwfulSettings.sharedSettings().showThreadTags
        if cell.showsTag {
            if let imageName = message.threadTag?.imageName {
                if let image = ThreadTagLoader.imageNamed(imageName) {
                    cell.tagImageView.image = image
                } else {
                    cell.tagImageView.image = ThreadTagLoader.emptyPrivateMessageImage
                    
                    let messageID = message.messageID
                    threadTagObservers[messageID] = NewThreadTagObserver(imageName: imageName) { [unowned self] image in
                        if let indexPath = tableView.indexPathForCell(cell) {
                            let message = self.itemAtIndexPath(indexPath) as! PrivateMessage
                            if message.messageID == messageID {
                                cell.tagImageView.image = image
                            }
                        }
                        self.threadTagObservers.removeValueForKey(messageID)
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
        let sentDateString = stringForSentDate(message.sentDate)
        cell.dateLabel.text = sentDateString
        cell.subjectLabel.text = message.subject
        
        var accessibilityLabel = message.fromUsername ?? ""
        accessibilityLabel += ". " + (message.subject ?? "")
        accessibilityLabel += ". " + sentDateString
        cell.accessibilityLabel = accessibilityLabel
        
        return cell
    }
    
    private func stringForSentDate(date: NSDate?) -> String {
        if let date = date {
            let calendar = NSCalendar.currentCalendar()
            let units: NSCalendarUnit = [.Day, .Month, .Year]
            let components = calendar.components(units, fromDate: date)
            let today = calendar.components(units, fromDate: NSDate())
            let formatter = components == today ? timeFormatter : dateFormatter
            return formatter.stringFromDate(date)
        } else {
            return ""
        }
    }
    
    private lazy var dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .NoStyle
        formatter.doesRelativeDateFormatting = true
        return formatter
        }()
    
    private lazy var timeFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .NoStyle
        formatter.timeStyle = .ShortStyle
        return formatter
        }()
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let message = itemAtIndexPath(indexPath) as! PrivateMessage
            deletionDelegate?.deleteMessage(message)
        }
    }
}
