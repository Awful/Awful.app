//  MessageComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

/// For writing private messages.
final class MessageComposeViewController: ComposeTextViewController {
    private let recipient: User?
    private let regardingMessage: PrivateMessage?
    private let forwardingMessage: PrivateMessage?
    private let initialContents: String?
    private var threadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    private var availableThreadTags: [ThreadTag]?
    private var updatingThreadTags = false
    private var threadTagPicker: ThreadTagPickerViewController?
    
    private lazy var fieldView: NewPrivateMessageFieldView = {
        let fieldView = NewPrivateMessageFieldView(frame: CGRect(x: 0, y: 0, width: 0, height: 88))
        fieldView.toField.label.textColor = .grayColor()
        fieldView.subjectField.label.textColor = .grayColor()
        fieldView.threadTagButton.addTarget(self, action: #selector(didTapThreadTagButton), forControlEvents: .TouchUpInside)
        fieldView.toField.textField.addTarget(self, action: #selector(toFieldDidChange), forControlEvents: .EditingChanged)
        fieldView.subjectField.textField.addTarget(self, action: #selector(subjectFieldDidChange), forControlEvents: .EditingChanged)
        return fieldView
    }()
    
    init() {
        recipient = nil
        regardingMessage = nil
        forwardingMessage = nil
        initialContents = nil
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }
    
    init(recipient: User) {
        self.recipient = recipient
        regardingMessage = nil
        forwardingMessage = nil
        initialContents = nil
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }
    
    init(regardingMessage: PrivateMessage, initialContents: String?) {
        self.regardingMessage = regardingMessage
        recipient = nil
        forwardingMessage = nil
        self.initialContents = initialContents
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }
    
    init(forwardingMessage: PrivateMessage, initialContents: String?) {
        self.forwardingMessage = forwardingMessage
        recipient = nil
        regardingMessage = nil
        self.initialContents = initialContents
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        title = "Private Message"
        submitButtonItem.title = "Send"
        restorationClass = self.dynamicType
    }
    
    private func updateThreadTagButtonImage() {
        let image: UIImage
        if let
            imageName = threadTag?.imageName,
            loadedImage = ThreadTagLoader.imageNamed(imageName)
        {
            image = loadedImage
        } else {
            image = ThreadTagLoader.unsetThreadTagImage
        }
        fieldView.threadTagButton.setImage(image, forState: .Normal)
    }
    
    private func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags?.isEmpty ?? true else { return }
        guard !updatingThreadTags else { return }
        AwfulForumsClient.sharedClient().listAvailablePrivateMessageThreadTagsAndThen { [weak self] (error, threadTags) in
            self?.updatingThreadTags = false
            
            if let threadTags = threadTags as? [ThreadTag] {
                self?.availableThreadTags = threadTags
                
                let imageNames = [ThreadTagLoader.emptyPrivateMessageImageName] + threadTags.flatMap { $0.imageName }
                let picker = ThreadTagPickerViewController(imageNames: imageNames, secondaryImageNames: nil)
                picker.delegate = self
                picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                self?.threadTagPicker = picker
            }
        }
    }
    
    override var canSubmitComposition: Bool {
        return super.canSubmitComposition &&
        fieldView.toField.textField.text?.isEmpty == false &&
        fieldView.subjectField.textField.text?.isEmpty == false
    }
    
    override var submissionInProgressTitle: String {
        return "Sending…"
    }
    
    override func submitComposition(composition: String!, completionHandler: ((Bool) -> Void)!) {
        guard let
            to = fieldView.toField.textField.text,
            subject = fieldView.subjectField.textField.text,
            threadTag = threadTag
            else { return }
        AwfulForumsClient.sharedClient().sendPrivateMessageTo(to, withSubject: subject, threadTag: threadTag, BBcode: composition, asReplyToMessage: regardingMessage, forwardedFromMessage: forwardingMessage) { [weak self] (error) in
            if let error = error {
                completionHandler(false)
                self?.presentViewController(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
            } else {
                completionHandler(true)
            }
        }
    }
    
    @objc private func didTapThreadTagButton(sender: ThreadTagButton) {
        guard let picker = threadTagPicker else { return }
        
        let selectedImageName = threadTag?.imageName ?? ThreadTagLoader.emptyPrivateMessageImageName
        picker.selectImageName(selectedImageName)
        picker.present(fromView: sender)
        
        // HACK: Calling -endEditing: once doesn't work if the To or Subject fields are selected. But twice works. I assume this is some weirdness from adding text fields as subviews to a text view.
        view.endEditing(true)
        view.endEditing(true)
    }
    
    @objc private func toFieldDidChange() {
        updateSubmitButtonItem()
    }
    
    @objc private func subjectFieldDidChange() {
        updateSubmitButtonItem()
    }
    
    // MARK: View lifecycle
    
    override func loadView() {
        super.loadView()
        customView = fieldView
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        fieldView.toField.textField.textColor = textView.textColor
        fieldView.toField.textField.keyboardAppearance = textView.keyboardAppearance
        fieldView.subjectField.textField.textColor = textView.textColor
        fieldView.subjectField.textField.keyboardAppearance = textView.keyboardAppearance
        
        let attributes = [NSForegroundColorAttributeName: theme["placeholderTextColor"] as UIColor? ?? .grayColor()]
        fieldView.toField.textField.attributedPlaceholder = NSAttributedString(string: "To", attributes: attributes)
        fieldView.subjectField.textField.attributedPlaceholder = NSAttributedString(string: "Subject", attributes: attributes)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateThreadTagButtonImage()
        
        if let recipient = recipient {
            if fieldView.toField.textField.text?.isEmpty ?? true {
                fieldView.toField.textField.text = recipient.username
            }
        } else if let regardingMessage = regardingMessage {
            if fieldView.toField.textField.text?.isEmpty ?? true {
                fieldView.toField.textField.text = regardingMessage.from?.username
            }
            
            if fieldView.subjectField.textField.text?.isEmpty ?? true {
                var subject = regardingMessage.subject ?? ""
                if !subject.hasPrefix("Re: ") {
                    subject = "Re: \(subject)"
                }
                fieldView.subjectField.textField.text = subject
            }
            
            if let initialContents = initialContents where textView.text.isEmpty {
                textView.text = initialContents
            }
        } else if let forwardingMessage = forwardingMessage {
            if fieldView.subjectField.textField.text?.isEmpty ?? true {
                fieldView.subjectField.textField.text = "Fw: \(forwardingMessage.subject ?? "")"
            }
            
            if let initialContents = initialContents where textView.text.isEmpty {
                textView.text = initialContents
            }
        }
        
        updateAvailableThreadTagsIfNecessary()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        updateAvailableThreadTagsIfNecessary()
    }
    
    // MARK: State restoration
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(recipient?.objectKey, forKey: Keys.RecipientUserKey.rawValue)
        coder.encodeObject(regardingMessage?.objectKey, forKey: Keys.RegardingMessageKey.rawValue)
        coder.encodeObject(forwardingMessage?.objectKey, forKey: Keys.ForwardingMessageKey.rawValue)
        coder.encodeObject(initialContents, forKey: Keys.InitialContents.rawValue)
        coder.encodeObject(threadTag?.objectKey, forKey: Keys.ThreadTagKey.rawValue)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        let context = AwfulAppDelegate.instance().managedObjectContext
        if let threadTagKey = coder.decodeObjectForKey(Keys.ThreadTagKey.rawValue) as? ThreadTagKey {
            threadTag = ThreadTag.objectForKey(threadTagKey, inManagedObjectContext: context) as? ThreadTag
        }
        
        super.decodeRestorableStateWithCoder(coder)
    }
}

extension MessageComposeViewController: ThreadTagPickerViewControllerDelegate {
    func threadTagPicker(picker: ThreadTagPickerViewController, didSelectImageName imageName: String) {
        if imageName == ThreadTagLoader.emptyPrivateMessageImageName {
            threadTag = nil
        } else if let
            availableThreadTags = availableThreadTags,
            i = availableThreadTags.indexOf({ $0.imageName == imageName })
        {
            threadTag = availableThreadTags[i]
        }
        
        picker.dismiss()
        
        focusInitialFirstResponder()
    }
}

extension MessageComposeViewController: UIViewControllerRestoration {
    static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        let recipientKey = coder.decodeObjectForKey(Keys.RecipientUserKey.rawValue) as? UserKey
        let regardingKey = coder.decodeObjectForKey(Keys.RegardingMessageKey.rawValue) as? PrivateMessageKey
        let forwardingKey = coder.decodeObjectForKey(Keys.ForwardingMessageKey.rawValue) as? PrivateMessageKey
        let initialContents = coder.decodeObjectForKey(Keys.InitialContents.rawValue) as? String
        let context = AwfulAppDelegate.instance().managedObjectContext
        
        let composeViewController: MessageComposeViewController
        if let
            recipientKey = recipientKey,
            recipient = User.objectForKey(recipientKey, inManagedObjectContext: context) as? User
        {
            composeViewController = MessageComposeViewController(recipient: recipient)
        } else if let
            regardingKey = regardingKey,
            regardingMessage = PrivateMessage.objectForKey(regardingKey, inManagedObjectContext: context) as? PrivateMessage
        {
            composeViewController = MessageComposeViewController(regardingMessage: regardingMessage, initialContents: initialContents)
        } else if let
            forwardingKey = forwardingKey,
            forwardingMessage = PrivateMessage.objectForKey(forwardingKey, inManagedObjectContext: context) as? PrivateMessage
        {
            composeViewController = MessageComposeViewController(forwardingMessage: forwardingMessage, initialContents: initialContents)
        } else {
            return nil
        }
        composeViewController.restorationIdentifier = identifierComponents.last as? String
        return composeViewController
    }
}

private enum Keys: String {
    case RecipientUserKey
    case RegardingMessageKey
    case ForwardingMessageKey
    case InitialContents
    case ThreadTagKey
}
