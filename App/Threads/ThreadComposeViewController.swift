//  ThreadComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

/// For writing the OP of a new thread.
final class ThreadComposeViewController: ComposeTextViewController {
    /// The newly-posted thread.
    fileprivate(set) var thread: AwfulThread?
    fileprivate let forum: Forum
    fileprivate var threadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    fileprivate var secondaryThreadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    fileprivate var fieldView: NewThreadFieldView!
    fileprivate var availableThreadTags: [ThreadTag]?
    fileprivate var availableSecondaryThreadTags: [ThreadTag]?
    fileprivate var updatingThreadTags = false
    fileprivate var onAppearBlock: (() -> Void)?
    fileprivate var threadTagPicker: ThreadTagPickerViewController?
    
    /// - parameter forum: The forum in which the new thread is posted.
    init(forum: Forum) {
        self.forum = forum
        super.init(nibName: nil, bundle: nil)
        
        title = defaultTitle
        submitButtonItem.title = "Preview"
        restorationClass = type(of: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    override func loadView() {
        super.loadView()
        
        fieldView = NewThreadFieldView(frame: CGRect(x: 0, y: 0, width: 0, height: 45))
        fieldView.subjectField.label.textColor = .gray
        fieldView.threadTagButton.addTarget(self, action: #selector(didTapThreadTagButton), for: .touchUpInside)
        fieldView.subjectField.textField.addTarget(self, action: #selector(subjectFieldDidChange), for: .editingChanged)
        customView = fieldView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTweaks()
        updateThreadTagButtonImage()
        updateAvailableThreadTagsIfNecessary()
    }
    
    override var theme: Theme {
        return Theme.currentThemeForForum(forum: forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        fieldView.subjectField.textField.textColor = textView.textColor
        fieldView.subjectField.textField.keyboardAppearance = textView.keyboardAppearance
        
        let attributes = [NSForegroundColorAttributeName: theme["placeholderTextColor"] ?? .gray]
        let themedString = NSAttributedString(string: "Subject", attributes: attributes)
        fieldView.subjectField.textField.attributedPlaceholder = themedString
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAvailableThreadTagsIfNecessary()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onAppearBlock?()
        onAppearBlock = nil
    }
    
    fileprivate func updateTweaks() {
        guard let tweaks = ForumTweaks(forumID: forum.forumID) else { return }
        fieldView.subjectField.textField.autocapitalizationType = tweaks.autocapitalizationType
        fieldView.subjectField.textField.autocorrectionType = tweaks.autocorrectionType
        fieldView.subjectField.textField.spellCheckingType = tweaks.spellCheckingType
        
        textView.autocapitalizationType = tweaks.autocapitalizationType
        textView.autocorrectionType = tweaks.autocorrectionType
        textView.spellCheckingType = tweaks.spellCheckingType
    }
    
    fileprivate func updateThreadTagButtonImage() {
        let image: UIImage?
        if let imageName = threadTag?.imageName {
            image = ThreadTagLoader.imageNamed(imageName)
        } else {
            image = ThreadTagLoader.unsetThreadTagImage
        }
        fieldView.threadTagButton.setImage(image, for: UIControlState())
        
        let secondaryImage: UIImage?
        if let imageName = secondaryThreadTag?.imageName {
            secondaryImage = ThreadTagLoader.imageNamed(imageName)
        } else {
            secondaryImage = nil
        }
        fieldView.threadTagButton.secondaryTagImage = secondaryImage
    }
    
    @objc fileprivate func didTapThreadTagButton(_ sender: UIButton) {
        guard let picker = threadTagPicker else { return }
        
        let selectedImageName = threadTag?.imageName ?? ThreadTagLoader.emptyThreadTagImageName
        picker.selectImageName(selectedImageName)
        
        if let
            secondaryTags = availableSecondaryThreadTags,
            let secondaryImageName = secondaryThreadTag?.imageName ?? secondaryTags.first?.imageName
        {
            picker.selectSecondaryImageName(secondaryImageName)
        }
        
        picker.present(fromView: sender)
        
        // HACK: Calling -endEditing: once doesn't work if the Subject field is selected. But twice works. I assume this is some weirdness from adding a text field as a subview to a text view.
        view.endEditing(true)
        view.endEditing(true)
    }
    
    @objc fileprivate func subjectFieldDidChange(_ sender: UITextField) {
        if let text = sender.text , !text.isEmpty {
            title = text
        } else {
            title = defaultTitle
        }
        
        updateSubmitButtonItem()
    }
    
    fileprivate func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags == nil && !updatingThreadTags else { return }
        
        updatingThreadTags = true
        _ = ForumsClient.shared.listAvailablePostIcons(inForumIdentifiedBy: forum.forumID)
            .then { [weak self] (form) -> Void in
                guard let sself = self else { return }
                sself.updatingThreadTags = false
                sself.availableThreadTags = form.threadTags
                sself.availableSecondaryThreadTags = form.secondaryThreadTags
                guard let tags = sself.availableThreadTags else { return }

                let imageNames = [ThreadTagLoader.emptyThreadTagImageName] + tags.flatMap { $0.imageName }
                let secondaryImageNames = sself.availableSecondaryThreadTags?.flatMap { $0.imageName }
                let picker = ThreadTagPickerViewController(imageNames: imageNames, secondaryImageNames: secondaryImageNames)
                sself.threadTagPicker = picker
                picker.delegate = sself
                picker.title = "Choose Thread Tag"
                if secondaryImageNames?.isEmpty == false {
                    picker.navigationItem.rightBarButtonItem = picker.doneButtonItem
                } else {
                    picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                }
            }
            .catch { [weak self] (error) -> Void in
                guard let sself = self else { return }
                sself.updatingThreadTags = false
                sself.availableThreadTags = nil
                sself.availableSecondaryThreadTags = nil
        }
    }
    
    override var canSubmitComposition: Bool {
        guard super.canSubmitComposition else { return false }
        guard fieldView.subjectField.textField.text?.isEmpty == false else { return false }
        return threadTag != nil
    }
    
    override func shouldSubmit(_ handler: @escaping (Bool) -> Void) {
        guard let
            subject = fieldView.subjectField.textField.text,
            let threadTag = threadTag
            else { return handler(false) }
        let preview = ThreadPreviewViewController(forum: forum, subject: subject, threadTag: threadTag, secondaryThreadTag: secondaryThreadTag, BBcode: textView.attributedText)
        preview.submitBlock = { handler(true) }
        onAppearBlock = { handler(false) }
        navigationController?.pushViewController(preview, animated: true)
    }
    
    override var submissionInProgressTitle: String {
        return "Posting…"
    }
    
    override func submit(_ composition: String, completion: @escaping (Bool) -> Void) {
        guard
            let subject = fieldView.subjectField.textField.text,
            let threadTag = threadTag
            else { return completion(false) }
        
        _ = ForumsClient.shared.postThread(in: forum, subject: subject, threadTag: threadTag, secondaryTag: secondaryThreadTag, bbcode: composition)
            .then { [weak self] (thread) -> Void in
                self?.thread = thread
                completion(true)
            }
            .catch { [weak self] (error) -> Void in
                let alert = UIAlertController(title: "Network Error", error: error, handler: { (action) in
                    completion(false)
                })
                self?.present(alert, animated: true, completion: nil)
        }
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(forum.objectKey, forKey: Keys.ForumKey.rawValue)
        coder.encode(fieldView.subjectField.textField.text, forKey: Keys.SubjectKey.rawValue)
        coder.encode(threadTag?.objectKey, forKey: Keys.ThreadTagKey.rawValue)
        coder.encode(secondaryThreadTag?.objectKey, forKey: Keys.SecondaryThreadTagKey.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        fieldView.subjectField.textField.text = coder.decodeObject(forKey: Keys.SubjectKey.rawValue) as? String
        
        if let tagKey = coder.decodeObject(forKey: Keys.ThreadTagKey.rawValue) as? ThreadTagKey {
            threadTag = ThreadTag.objectForKey(objectKey: tagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        if let secondaryTagKey = coder.decodeObject(forKey: Keys.SecondaryThreadTagKey.rawValue) as? ThreadTagKey {
            secondaryThreadTag = ThreadTag.objectForKey(objectKey: secondaryTagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        super.decodeRestorableState(with: coder)
    }
}

extension ThreadComposeViewController: ThreadTagPickerViewControllerDelegate {
    func threadTagPicker(_ picker: ThreadTagPickerViewController, didSelectImageName imageName: String) {
        if imageName == ThreadTagLoader.emptyThreadTagImageName {
            threadTag = nil
        } else if let
            threadTags = availableThreadTags,
            let i = threadTags.index(where: { $0.imageName == imageName})
        {
            threadTag = threadTags[i]
        }
        
        if availableSecondaryThreadTags?.isEmpty ?? true {
            picker.dismiss()
            focusInitialFirstResponder()
        }
    }
    
    func threadTagPicker(_ picker: ThreadTagPickerViewController, didSelectSecondaryImageName imageName: String) {
        if let
            tags = availableSecondaryThreadTags,
            let i = tags.index(where: { $0.imageName == imageName })
        {
            secondaryThreadTag = tags[i]
        }
    }
    
    func threadTagPickerDidDismiss(_ picker: ThreadTagPickerViewController) {
        focusInitialFirstResponder()
    }
}

extension ThreadComposeViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        guard let
            forumKey = coder.decodeObject(forKey: Keys.ForumKey.rawValue) as? ForumKey,
            let forum = Forum.objectForKey(objectKey: forumKey, inManagedObjectContext: AppDelegate.instance.managedObjectContext) as? Forum
            else { return nil }
        
        let composeViewController = ThreadComposeViewController(forum: forum)
        composeViewController.restorationIdentifier = identifierComponents.last as? String
        return composeViewController
    }
}

private let defaultTitle = "New Thread"

private enum Keys: String {
    case ForumKey
    case SubjectKey = "AwfulSubject"
    case ThreadTagKey
    case SecondaryThreadTagKey
}
