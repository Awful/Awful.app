//  MessageComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Nuke
import UIKit

/// For writing private messages.
final class MessageComposeViewController: ComposeTextViewController {
    fileprivate let recipient: User?
    fileprivate let regardingMessage: PrivateMessage?
    fileprivate let forwardingMessage: PrivateMessage?
    fileprivate let initialContents: String?
    fileprivate var threadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    fileprivate var availableThreadTags: [ThreadTag]?
    fileprivate var updatingThreadTags = false
    fileprivate var threadTagPicker: ThreadTagPickerViewController?
    
    fileprivate lazy var fieldView: NewPrivateMessageFieldView = {
        let fieldView = NewPrivateMessageFieldView(frame: CGRect(x: 0, y: 0, width: 0, height: 88))
        fieldView.toField.label.textColor = .gray
        fieldView.subjectField.label.textColor = .gray
        fieldView.threadTagButton.addTarget(self, action: #selector(didTapThreadTagButton), for: .touchUpInside)
        fieldView.toField.textField.addTarget(self, action: #selector(toFieldDidChange), for: .editingChanged)
        fieldView.subjectField.textField.addTarget(self, action: #selector(subjectFieldDidChange), for: .editingChanged)
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
    
    fileprivate func commonInit() {
        title = "Private Message"
        submitButtonItem.title = "Send"
        restorationClass = type(of: self)
    }
    
    private var threadTagTask: ImageTask?
    
    fileprivate func updateThreadTagButtonImage() {
        threadTagTask?.cancel()
        fieldView.threadTagButton.setImage(ThreadTagLoader.Placeholder.thread(tintColor: nil).image, for: .normal)
        
        threadTagTask = ThreadTagLoader.shared.loadImage(named: threadTag?.imageName) { [fieldView] response, error in
            if let image = response?.image {
                fieldView.threadTagButton.setImage(image, for: .normal)
            }
        }
    }
    
    fileprivate func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags?.isEmpty ?? true else { return }
        guard !updatingThreadTags else { return }
        _ = ForumsClient.shared.listAvailablePrivateMessageThreadTags()
            .done { [weak self] threadTags in
                self?.availableThreadTags = threadTags

                let picker = ThreadTagPickerViewController(
                    firstTag: .privateMessage,
                    imageNames: threadTags.compactMap { $0.imageName },
                    secondaryImageNames: [])
                picker.delegate = self
                picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                self?.threadTagPicker = picker
            }
            .ensure { [weak self] in
                self?.updatingThreadTags = false
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
    
    override func submit(_ composition: String, completion: @escaping (Bool) -> Void) {
        guard let
            to = fieldView.toField.textField.text,
            let subject = fieldView.subjectField.textField.text
            else { return }
        _ = ForumsClient.shared.sendPrivateMessage(to: to, subject: subject, threadTag: threadTag, bbcode: composition, regarding: regardingMessage, forwarding: forwardingMessage)
            .done {
                completion(true)
            }
            .catch { [weak self] error in
                completion(false)
                self?.present(UIAlertController(networkError: error), animated: true)
        }
    }
    
    @objc fileprivate func didTapThreadTagButton(_ sender: ThreadTagButton) {
        guard let picker = threadTagPicker else { return }
        
        picker.selectImageName(threadTag?.imageName)
        picker.present(from: self, sourceView: sender)
        
        // HACK: Calling -endEditing: once doesn't work if the To or Subject fields are selected. But twice works. I assume this is some weirdness from adding text fields as subviews to a text view.
        view.endEditing(true)
        view.endEditing(true)
    }
    
    @objc fileprivate func toFieldDidChange() {
        updateSubmitButtonItem()
    }
    
    @objc fileprivate func subjectFieldDidChange() {
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
        
        let attributes = [NSAttributedString.Key.foregroundColor: theme[color: "placeholderTextColor"] ?? .gray]
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
            
            if let initialContents = initialContents , textView.text.isEmpty {
                textView.text = initialContents
            }
        } else if let forwardingMessage = forwardingMessage {
            if fieldView.subjectField.textField.text?.isEmpty ?? true {
                fieldView.subjectField.textField.text = "Fw: \(forwardingMessage.subject ?? "")"
            }
            
            if let initialContents = initialContents , textView.text.isEmpty {
                textView.text = initialContents
            }
        }
        
        updateAvailableThreadTagsIfNecessary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateAvailableThreadTagsIfNecessary()
    }
    
    // MARK: State restoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(recipient?.objectKey, forKey: Keys.RecipientUserKey.rawValue)
        coder.encode(regardingMessage?.objectKey, forKey: Keys.RegardingMessageKey.rawValue)
        coder.encode(forwardingMessage?.objectKey, forKey: Keys.ForwardingMessageKey.rawValue)
        coder.encode(initialContents, forKey: Keys.InitialContents.rawValue)
        coder.encode(threadTag?.objectKey, forKey: Keys.ThreadTagKey.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        let context = AppDelegate.instance.managedObjectContext
        if let threadTagKey = coder.decodeObject(forKey: Keys.ThreadTagKey.rawValue) as? ThreadTagKey {
            threadTag = ThreadTag.objectForKey(objectKey: threadTagKey, inManagedObjectContext: context) as? ThreadTag
        }
        
        super.decodeRestorableState(with: coder)
    }
}

extension MessageComposeViewController: ThreadTagPickerViewControllerDelegate {
    
    func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController) {
        if
            let imageName = imageName,
            let availableThreadTags = availableThreadTags,
            let i = availableThreadTags.firstIndex(where: { $0.imageName == imageName })
        {
            threadTag = availableThreadTags[i]
        } else {
            threadTag = nil
        }
        
        picker.dismiss()
        
        focusInitialFirstResponder()
    }
    
    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
        // nop
    }
    
    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        // nop
    }
}

extension MessageComposeViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        let recipientKey = coder.decodeObject(forKey: Keys.RecipientUserKey.rawValue) as? UserKey
        let regardingKey = coder.decodeObject(forKey: Keys.RegardingMessageKey.rawValue) as? PrivateMessageKey
        let forwardingKey = coder.decodeObject(forKey: Keys.ForwardingMessageKey.rawValue) as? PrivateMessageKey
        let initialContents = coder.decodeObject(forKey: Keys.InitialContents.rawValue) as? String
        let context = AppDelegate.instance.managedObjectContext
        
        let composeViewController: MessageComposeViewController
        if let
            recipientKey = recipientKey,
            let recipient = User.objectForKey(objectKey: recipientKey, inManagedObjectContext: context) as? User
        {
            composeViewController = MessageComposeViewController(recipient: recipient)
        } else if let
            regardingKey = regardingKey,
            let regardingMessage = PrivateMessage.objectForKey(objectKey: regardingKey, inManagedObjectContext: context) as? PrivateMessage
        {
            composeViewController = MessageComposeViewController(regardingMessage: regardingMessage, initialContents: initialContents)
        } else if let
            forwardingKey = forwardingKey,
            let forwardingMessage = PrivateMessage.objectForKey(objectKey: forwardingKey, inManagedObjectContext: context) as? PrivateMessage
        {
            composeViewController = MessageComposeViewController(forwardingMessage: forwardingMessage, initialContents: initialContents)
        } else {
            return nil
        }
        composeViewController.restorationIdentifier = identifierComponents.last
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
