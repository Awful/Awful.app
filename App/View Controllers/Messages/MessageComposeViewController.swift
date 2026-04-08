//  MessageComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Nuke
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageComposeViewController")

/// For writing private messages.
final class MessageComposeViewController: ComposeTextViewController {
    fileprivate let recipient: User?
    fileprivate let regardingMessage: PrivateMessage?
    fileprivate let forwardingMessage: PrivateMessage?
    fileprivate let initialContents: String?
    private let draft: PrivateMessageDraft
    private var autoSaveWorkItem: DispatchWorkItem?
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
        self.draft = Self.loadDraft(kind: .new)
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    init(recipient: User) {
        self.recipient = recipient
        regardingMessage = nil
        forwardingMessage = nil
        initialContents = nil
        self.draft = Self.loadDraft(kind: .to(recipient))
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    init(regardingMessage: PrivateMessage, initialContents: String?) {
        self.regardingMessage = regardingMessage
        recipient = nil
        forwardingMessage = nil
        self.initialContents = initialContents
        self.draft = Self.loadDraft(kind: .replying(to: regardingMessage))
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    init(forwardingMessage: PrivateMessage, initialContents: String?) {
        self.forwardingMessage = forwardingMessage
        recipient = nil
        regardingMessage = nil
        self.initialContents = initialContents
        self.draft = Self.loadDraft(kind: .forwarding(forwardingMessage))
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        autoSaveWorkItem?.cancel()
    }

    /// Returns a fresh draft if no on-disk draft exists for the given kind, otherwise the loaded
    /// draft. Resolving the on-disk path doesn't depend on the actual `PrivateMessage` instance,
    /// just its message ID, so this works at init time before any properties are set.
    private static func loadDraft(kind: PrivateMessageDraft.Kind) -> PrivateMessageDraft {
        let placeholder = PrivateMessageDraft(kind: kind)
        if let saved = DraftStore.sharedStore().loadDraft(placeholder.storePath) as? PrivateMessageDraft {
            return saved
        }
        return placeholder
    }

    fileprivate func commonInit() {
        title = "Private Message"
        submitButtonItem.title = "Send"
    }
    
    private var threadTagTask: ImageTask?
    
    fileprivate func updateThreadTagButtonImage() {
        threadTagTask?.cancel()
        fieldView.threadTagButton.setImage(ThreadTagLoader.Placeholder.thread(tintColor: nil).image, for: .normal)
        
        threadTagTask = ThreadTagLoader.shared.loadImage(named: threadTag?.imageName) { [fieldView] result in
            switch result {
            case .success(let response):
                fieldView.threadTagButton.setImage(response.image, for: .normal)
            case .failure:
                break
            }
        }
    }
    
    fileprivate func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags?.isEmpty ?? true else { return }
        guard !updatingThreadTags else { return }
        Task {
            do {
                let threadTags = try await ForumsClient.shared.listAvailablePrivateMessageThreadTags()
                availableThreadTags = threadTags

                let picker = ThreadTagPickerViewController(
                    firstTag: .privateMessage,
                    imageNames: threadTags.compactMap { $0.imageName },
                    secondaryImageNames: [])
                picker.delegate = self
                picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                threadTagPicker = picker
            } catch {
                logger.error("Could not list available private message thread tags: \(error)")
            }

            updatingThreadTags = false
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
        guard let to = fieldView.toField.textField.text,
              !to.isEmpty,
              let subject = fieldView.subjectField.textField.text,
              !subject.isEmpty
        else { return }
        Task {
            do {
                let relevant: ForumsClient.RelevantMessage
                if let regardingMessage {
                    relevant = .replyingTo(regardingMessage)
                } else if let forwardingMessage {
                    relevant = .forwarding(forwardingMessage)
                } else {
                    relevant = .none
                }
                try await ForumsClient.shared.sendPrivateMessage(to: to, subject: subject, threadTag: threadTag, bbcode: composition, about: relevant)
                deleteDraft()
                completion(true)
            } catch {
                completion(false)
                present(UIAlertController(networkError: error), animated: true)
            }
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
        scheduleDraftAutoSave()
    }

    @objc fileprivate func subjectFieldDidChange() {
        updateSubmitButtonItem()
        scheduleDraftAutoSave()
    }

    override func bodyTextDidChange() {
        scheduleDraftAutoSave()
    }

    private func scheduleDraftAutoSave() {
        autoSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveDraftNow() }
        autoSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Synchronously runs any pending auto-save. Called on dismissal so the last keystrokes
    /// aren't lost to the 0.5 s debounce.
    private func flushDraftAutoSave() {
        guard autoSaveWorkItem != nil else { return }
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        saveDraftNow()
    }

    private func saveDraftNow() {
        draft.to = fieldView.toField.textField.text ?? ""
        draft.subject = fieldView.subjectField.textField.text ?? ""
        draft.threadTag = threadTag
        draft.text = textView.attributedText
        if draft.to.isEmpty
            && draft.subject.isEmpty
            && draft.threadTag == nil
            && (draft.text?.length ?? 0) == 0
        {
            DraftStore.sharedStore().deleteDraft(draft)
        } else {
            DraftStore.sharedStore().saveDraft(draft)
        }
    }

    private func deleteDraft() {
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        DraftStore.sharedStore().deleteDraft(draft)
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
        
        let attributes = [NSAttributedString.Key.foregroundColor: theme[uicolor: "placeholderTextColor"] ?? .gray]
        fieldView.toField.textField.attributedPlaceholder = NSAttributedString(string: "To", attributes: attributes)
        fieldView.subjectField.textField.attributedPlaceholder = NSAttributedString(string: "Subject", attributes: attributes)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        threadTag = draft.threadTag
        updateThreadTagButtonImage()

        // Saved-draft contents take precedence over the defaults derived from the recipient or
        // the message being replied to/forwarded — the draft already incorporates any user edits.
        if !draft.to.isEmpty {
            fieldView.toField.textField.text = draft.to
        } else if let recipient = recipient {
            fieldView.toField.textField.text = recipient.username
        } else if let regardingMessage = regardingMessage {
            fieldView.toField.textField.text = regardingMessage.from?.username
        }

        if !draft.subject.isEmpty {
            fieldView.subjectField.textField.text = draft.subject
        } else if let regardingMessage = regardingMessage {
            var subject = regardingMessage.subject ?? ""
            if !subject.hasPrefix("Re: ") {
                subject = "Re: \(subject)"
            }
            fieldView.subjectField.textField.text = subject
        } else if let forwardingMessage = forwardingMessage {
            fieldView.subjectField.textField.text = "Fw: \(forwardingMessage.subject ?? "")"
        }

        if let savedText = draft.text {
            textView.attributedText = savedText
            updateSubmitButtonItem()
        } else if let initialContents = initialContents, textView.text.isEmpty {
            textView.text = initialContents
        }

        updateAvailableThreadTagsIfNecessary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateAvailableThreadTagsIfNecessary()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Flush the debounced draft save on the way out so nothing the user typed in the last
        // 0.5 s is dropped if they dismiss immediately after typing.
        if isMovingFromParent || isBeingDismissed {
            flushDraftAutoSave()
        }
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
        scheduleDraftAutoSave()

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

