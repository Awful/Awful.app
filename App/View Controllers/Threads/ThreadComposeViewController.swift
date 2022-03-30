//  ThreadComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Nuke
import UIKit

/// For writing the OP of a new thread.
final class ThreadComposeViewController: ComposeTextViewController {
    /// The newly-posted thread.
    private(set) var thread: AwfulThread?
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
    private var formData: ForumsClient.PostNewThreadFormData?
    
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
        return Theme.currentTheme(for: forum)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        fieldView.subjectField.textField.textColor = textView.textColor
        fieldView.subjectField.textField.keyboardAppearance = textView.keyboardAppearance
        
        let attributes = [NSAttributedString.Key.foregroundColor: theme["listSecondaryTextColor"] ?? .gray]
        let themedString = NSAttributedString(string: "Subject", attributes: attributes)
        fieldView.subjectField.textField.attributedPlaceholder = themedString
        updateThreadTagButtonImage()
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
    
    private func updateTweaks() {
        guard let tweaks = ForumTweaks(forumID: forum.forumID) else { return }
        fieldView.subjectField.textField.autocapitalizationType = tweaks.autocapitalizationType
        fieldView.subjectField.textField.autocorrectionType = tweaks.autocorrectionType
        fieldView.subjectField.textField.spellCheckingType = tweaks.spellCheckingType
        
        textView.autocapitalizationType = tweaks.autocapitalizationType
        textView.autocorrectionType = tweaks.autocorrectionType
        textView.spellCheckingType = tweaks.spellCheckingType
    }
    
    private var threadTagImageTask: ImageTask?
    private var secondaryThreadTagImageTask: ImageTask?
    
    private func updateThreadTagButtonImage() {
        threadTagImageTask?.cancel()
        fieldView.threadTagButton.setImage(ThreadTagLoader.Placeholder.thread(in: forum).image, for: .normal)
        
        threadTagImageTask = ThreadTagLoader.shared.loadImage(named: threadTag?.imageName) {
            [button = fieldView.threadTagButton] result in
            switch result {
            case .success(let response):
                button.setImage(response.image, for: .normal)
            case .failure:
                break
            }
        }
        
        secondaryThreadTagImageTask?.cancel()
        fieldView.threadTagButton.secondaryTagImage = nil
        
        secondaryThreadTagImageTask = ThreadTagLoader.shared.loadImage(named: secondaryThreadTag?.imageName) {
            [button = fieldView.threadTagButton] result in
            switch result {
            case .success(let response):
                button.secondaryTagImage = response.image
            case .failure:
                break
            }
        }
    }
    
    @objc private func didTapThreadTagButton(_ sender: UIButton) {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        guard let picker = threadTagPicker else { return }
        
        picker.selectImageName(threadTag?.imageName)
        
        if
            let secondaryTags = availableSecondaryThreadTags,
            let secondaryImageName = secondaryThreadTag?.imageName ?? secondaryTags.first?.imageName
        {
            picker.selectSecondaryImageName(secondaryImageName)
        }
        
        picker.present(from: self, sourceView: sender)
        
        // HACK: Calling -endEditing: once doesn't work if the Subject field is selected. But twice works. I assume this is some weirdness from adding a text field as a subview to a text view.
        view.endEditing(true)
        view.endEditing(true)
    }
    
    @objc private func subjectFieldDidChange(_ sender: UITextField) {
        if let text = sender.text , !text.isEmpty {
            title = text
        } else {
            title = defaultTitle
        }
        
        updateSubmitButtonItem()
    }
    
    private func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags == nil && !updatingThreadTags else { return }
        
        updatingThreadTags = true
        ForumsClient.shared.listAvailablePostIcons(inForumIdentifiedBy: forum.forumID)
            .done { [weak self] tags in
                guard let self = self else { return }
                self.updatingThreadTags = false
                self.availableThreadTags = tags.primary
                self.availableSecondaryThreadTags = tags.secondary
                
                guard let tags = self.availableThreadTags else { return }
                let secondaryImageNames = self.availableSecondaryThreadTags?.compactMap { $0.imageName } ?? []
                let picker = ThreadTagPickerViewController(
                    firstTag: .thread(in: self.forum),
                    imageNames: tags.compactMap { $0.imageName },
                    secondaryImageNames: secondaryImageNames)
                self.threadTagPicker = picker
                picker.delegate = self
                picker.title = LocalizedString("compose.thread.tag-picker.title")
                if secondaryImageNames.isEmpty {
                    picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                } else {
                    picker.navigationItem.rightBarButtonItem = picker.doneButtonItem
                }
            }
            .catch { [weak self] error in
                guard let self = self else { return }
                self.updatingThreadTags = false
                self.availableThreadTags = nil
                self.availableSecondaryThreadTags = nil
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
        let preview = ThreadPreviewViewController(forum: forum, subject: subject, threadTag: threadTag, secondaryThreadTag: secondaryThreadTag, bbcode: textView.attributedText)
        preview.submitBlock = { [weak preview, weak self] in
            if let preview = preview, let self = self {
                self.formData = preview.formData
            }
            handler(true)
        }
        onAppearBlock = { handler(false) }
        navigationController?.pushViewController(preview, animated: true)
    }
    
    override var submissionInProgressTitle: String {
        return "Posting…"
    }
    
    override func submit(_ composition: String, completion: @escaping (Bool) -> Void) {
        guard
            let subject = fieldView.subjectField.textField.text,
            let threadTag = threadTag,
            let formData = formData
            else { return completion(false) }
        
        ForumsClient.shared.postThread(using: formData, subject: subject, threadTag: threadTag, secondaryTag: secondaryThreadTag, bbcode: composition)
            .done { [weak self] thread in
                self?.thread = thread
                completion(true)
            }
            .catch { [weak self] error in
                let alert = UIAlertController(title: "Network Error", error: error, handler: {
                    completion(false)
                })
                self?.present(alert, animated: true)
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
            threadTag = ThreadTag.objectForKey(objectKey: tagKey, in: forum.managedObjectContext!)
        }
        
        if let secondaryTagKey = coder.decodeObject(forKey: Keys.SecondaryThreadTagKey.rawValue) as? ThreadTagKey {
            secondaryThreadTag = ThreadTag.objectForKey(objectKey: secondaryTagKey, in: forum.managedObjectContext!)
        }
        
        super.decodeRestorableState(with: coder)
    }
}

extension ThreadComposeViewController: ThreadTagPickerViewControllerDelegate {
    
    func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController) {
        if
            let imageName = imageName,
            let threadTags = availableThreadTags,
            let i = threadTags.firstIndex(where: { $0.imageName == imageName})
        {
            threadTag = threadTags[i]
        } else {
            threadTag = nil
        }
        
        if availableSecondaryThreadTags?.isEmpty ?? true {
            picker.dismiss()
            focusInitialFirstResponder()
        }
    }
    
    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
        if
            let tags = availableSecondaryThreadTags,
            let i = tags.firstIndex(where: { $0.imageName == secondaryImageName })
        {
            secondaryThreadTag = tags[i]
        }
    }
    
    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        focusInitialFirstResponder()
    }
}

extension ThreadComposeViewController: UIViewControllerRestoration {
    static func viewController(
        withRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        guard let forumKey = coder.decodeObject(forKey: Keys.ForumKey.rawValue) as? ForumKey else { return nil }
        let forum = Forum.objectForKey(objectKey: forumKey, in: AppDelegate.instance.managedObjectContext)
        let composeViewController = ThreadComposeViewController(forum: forum)
        composeViewController.restorationIdentifier = identifierComponents.last
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
