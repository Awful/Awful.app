//  ThreadComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// For writing the OP of a new thread.
final class ThreadComposeViewController: ComposeTextViewController {
    /// The newly-posted thread.
    private(set) var thread: Thread?
    private let forum: Forum
    private var threadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    private var secondaryThreadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    private var fieldView: NewThreadFieldView!
    private var availableThreadTags: [ThreadTag]?
    private var availableSecondaryThreadTags: [ThreadTag]?
    private var updatingThreadTags = false
    private var onAppearBlock: (() -> Void)?
    private var threadTagPicker: ThreadTagPickerViewController?
    
    /// - parameter forum: The forum in which the new thread is posted.
    init(forum: Forum) {
        self.forum = forum
        super.init(nibName: nil, bundle: nil)
        
        title = defaultTitle
        submitButtonItem.title = "Preview"
        restorationClass = self.dynamicType
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
        fieldView.subjectField.label.textColor = .grayColor()
        fieldView.threadTagButton.addTarget(self, action: #selector(didTapThreadTagButton), forControlEvents: .TouchUpInside)
        fieldView.subjectField.textField.addTarget(self, action: #selector(subjectFieldDidChange), forControlEvents: .EditingChanged)
        customView = fieldView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTweaks()
        updateThreadTagButtonImage()
        updateAvailableThreadTagsIfNecessary()
    }
    
    override var theme: Theme! {
        return Theme.currentThemeForForum(forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        fieldView.subjectField.textField.textColor = textView.textColor
        fieldView.subjectField.textField.keyboardAppearance = textView.keyboardAppearance
        
        let attributes = [NSForegroundColorAttributeName: theme["placeholderTextColor"] ?? .grayColor()]
        let themedString = NSAttributedString(string: "Subject", attributes: attributes)
        fieldView.subjectField.textField.attributedPlaceholder = themedString
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateAvailableThreadTagsIfNecessary()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        onAppearBlock?()
        onAppearBlock = nil
    }
    
    private func updateTweaks() {
        guard let tweaks = ForumTweaks(forumID: forum.forumID) else { return }
        fieldView.subjectField.textField.autocapitalizationType = tweaks.autocapitalizationType
        fieldView.subjectField.textField.autocorrectionType = tweaks.autocorrectionType
        fieldView.subjectField.textField.spellCheckingType = tweaks.spellCheckingType
        
        textView.autocapitalizationType = tweaks.autocapitalizationType
        textView.autocorrectionType = tweaks.autocorrectionType
        textView.spellCheckingType = tweaks.spellCheckingType
    }
    
    private func updateThreadTagButtonImage() {
        let image: UIImage?
        if let imageName = threadTag?.imageName {
            image = ThreadTagLoader.imageNamed(imageName)
        } else {
            image = ThreadTagLoader.unsetThreadTagImage
        }
        fieldView.threadTagButton.setImage(image, forState: .Normal)
        
        let secondaryImage: UIImage?
        if let imageName = secondaryThreadTag?.imageName {
            secondaryImage = ThreadTagLoader.imageNamed(imageName)
        } else {
            secondaryImage = nil
        }
        fieldView.threadTagButton.secondaryTagImage = secondaryImage
    }
    
    @objc private func didTapThreadTagButton(sender: UIButton) {
        guard let picker = threadTagPicker else { return }
        
        let selectedImageName = threadTag?.imageName ?? ThreadTagLoader.emptyThreadTagImageName
        picker.selectImageName(selectedImageName)
        
        if let
            secondaryTags = availableSecondaryThreadTags,
            secondaryImageName = secondaryThreadTag?.imageName ?? secondaryTags.first?.imageName
        {
            picker.selectSecondaryImageName(secondaryImageName)
        }
        
        picker.present(fromView: sender)
        
        // HACK: Calling -endEditing: once doesn't work if the Subject field is selected. But twice works. I assume this is some weirdness from adding a text field as a subview to a text view.
        view.endEditing(true)
        view.endEditing(true)
    }
    
    @objc private func subjectFieldDidChange(sender: UITextField) {
        if let text = sender.text where !text.isEmpty {
            title = text
        } else {
            title = defaultTitle
        }
        
        updateSubmitButtonItem()
    }
    
    private func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags == nil && !updatingThreadTags else { return }
        
        updatingThreadTags = true
        AwfulForumsClient.sharedClient().listAvailablePostIconsForForumWithID(forum.forumID) { [weak self] (error, form) in
            self?.updatingThreadTags = false
            self?.availableThreadTags = form.threadTags as! [ThreadTag]?
            self?.availableSecondaryThreadTags = form.secondaryThreadTags as! [ThreadTag]?
            if let tags = self?.availableThreadTags {
                let imageNames = [ThreadTagLoader.emptyThreadTagImageName] + tags.flatMap { $0.imageName }
                let secondaryImageNames = self?.availableSecondaryThreadTags?.flatMap { $0.imageName }
                let picker = ThreadTagPickerViewController(imageNames: imageNames, secondaryImageNames: secondaryImageNames)
                self?.threadTagPicker = picker
                picker.delegate = self
                picker.title = "Choose Thread Tag"
                if secondaryImageNames?.isEmpty == false {
                    picker.navigationItem.rightBarButtonItem = picker.doneButtonItem
                } else {
                    picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                }
            }
        }
    }
    
    override var canSubmitComposition: Bool {
        guard super.canSubmitComposition else { return false }
        guard fieldView.subjectField.textField.text?.isEmpty == false else { return false }
        return threadTag != nil
    }
    
    override func shouldSubmit(handler: (Bool) -> Void) {
        guard let
            subject = fieldView.subjectField.textField.text,
            threadTag = threadTag
            else { return handler(false) }
        let preview = ThreadPreviewViewController(forum: forum, subject: subject, threadTag: threadTag, secondaryThreadTag: secondaryThreadTag, BBcode: textView.attributedText)
        preview.submitBlock = { handler(true) }
        onAppearBlock = { handler(false) }
        navigationController?.pushViewController(preview, animated: true)
    }
    
    override var submissionInProgressTitle: String {
        return "Posting…"
    }
    
    override func submit(composition: String, completion: (Bool) -> Void) {
        guard let
            subject = fieldView.subjectField.textField.text,
            threadTag = threadTag
            else { return completion(false) }
        AwfulForumsClient.sharedClient().postThreadInForum(forum, withSubject: subject, threadTag: threadTag, secondaryTag: secondaryThreadTag, BBcode: composition) { [weak self] (error, thread) in
            if let error = error {
                let alert = UIAlertController(title: "Network Error", error: error, handler: { (action) in
                    completion(false)
                })
                self?.presentViewController(alert, animated: true, completion: nil)
                return
            }
            
            self?.thread = thread
            completion(true)
        }
    }
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(forum.objectKey, forKey: Keys.ForumKey.rawValue)
        coder.encodeObject(fieldView.subjectField.textField.text, forKey: Keys.SubjectKey.rawValue)
        coder.encodeObject(threadTag?.objectKey, forKey: Keys.ThreadTagKey.rawValue)
        coder.encodeObject(secondaryThreadTag?.objectKey, forKey: Keys.SecondaryThreadTagKey.rawValue)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        fieldView.subjectField.textField.text = coder.decodeObjectForKey(Keys.SubjectKey.rawValue) as? String
        
        if let tagKey = coder.decodeObjectForKey(Keys.ThreadTagKey.rawValue) as? ThreadTagKey {
            threadTag = ThreadTag.objectForKey(tagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        if let secondaryTagKey = coder.decodeObjectForKey(Keys.SecondaryThreadTagKey.rawValue) as? ThreadTagKey {
            secondaryThreadTag = ThreadTag.objectForKey(secondaryTagKey, inManagedObjectContext: forum.managedObjectContext!) as? ThreadTag
        }
        
        super.decodeRestorableStateWithCoder(coder)
    }
}

extension ThreadComposeViewController: ThreadTagPickerViewControllerDelegate {
    func threadTagPicker(picker: ThreadTagPickerViewController, didSelectImageName imageName: String) {
        if imageName == ThreadTagLoader.emptyThreadTagImageName {
            threadTag = nil
        } else if let
            threadTags = availableThreadTags,
            i = threadTags.indexOf({ $0.imageName == imageName})
        {
            threadTag = threadTags[i]
        }
        
        if availableSecondaryThreadTags?.isEmpty ?? true {
            picker.dismiss()
            focusInitialFirstResponder()
        }
    }
    
    func threadTagPicker(picker: ThreadTagPickerViewController, didSelectSecondaryImageName imageName: String) {
        if let
            tags = availableSecondaryThreadTags,
            i = tags.indexOf({ $0.imageName == imageName })
        {
            secondaryThreadTag = tags[i]
        }
    }
    
    func threadTagPickerDidDismiss(picker: ThreadTagPickerViewController) {
        focusInitialFirstResponder()
    }
}

extension ThreadComposeViewController: UIViewControllerRestoration {
    static func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        guard let
            forumKey = coder.decodeObjectForKey(Keys.ForumKey.rawValue) as? ForumKey,
            forum = Forum.objectForKey(forumKey, inManagedObjectContext: AppDelegate.instance.managedObjectContext) as? Forum
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
