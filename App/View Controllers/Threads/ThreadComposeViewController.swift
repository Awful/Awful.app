//  ThreadComposeViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Nuke
import UIKit

/// For writing the OP of a new thread.
final class ThreadComposeViewController: ComposeTextViewController {
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    /// The newly-posted thread.
    private(set) var thread: AwfulThread?
    private let forum: Forum
    private var threadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    private var secondaryThreadTag: ThreadTag? {
        didSet { updateThreadTagButtonImage() }
    }
    private var poll: PollSubmission? {
        didSet {
            toolbarContainer?.pollIsAttached = poll != nil
            scheduleDraftAutoSave()
        }
    }

    override var showsPollButtonInToolbar: Bool { true }

    override func handleComposeToolbarAction(_ action: ModernToolbarAction) {
        if case .poll = action {
            presentPollEditor()
        } else {
            super.handleComposeToolbarAction(action)
        }
    }
    private var fieldView: NewThreadFieldView!
    private var availableThreadTags: [ThreadTag]?
    private var availableSecondaryThreadTags: [ThreadTag]?
    private var updatingThreadTags = false
    private var onAppearBlock: (() -> Void)?
    private var threadTagPicker: ThreadTagPickerViewController?
    private var formData: ForumsClient.PostNewThreadFormData?
    
    private let draft: NewThreadDraft
    private var autoSaveWorkItem: DispatchWorkItem?

    /// - parameter forum: The forum in which the new thread is posted. Loads any saved draft for
    ///   this forum from `DraftStore` so the in-progress thread is recovered across launches.
    init(forum: Forum) {
        self.forum = forum
        let saved = DraftStore.sharedStore().loadDraft("newThreads/\(forum.forumID)") as? NewThreadDraft
        self.draft = saved ?? NewThreadDraft(forum: forum)
        super.init(nibName: nil, bundle: nil)

        title = defaultTitle
        submitButtonItem.title = "Preview"
    }

    deinit {
        autoSaveWorkItem?.cancel()
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
        threadTag = draft.threadTag
        secondaryThreadTag = draft.secondaryThreadTag
        poll = draft.poll
        updateThreadTagButtonImage()
        updateAvailableThreadTagsIfNecessary()

        if !draft.subject.isEmpty {
            fieldView.subjectField.textField.text = draft.subject
            title = draft.subject
        }
        if let savedText = draft.text {
            textView.attributedText = savedText
            updateSubmitButtonItem()
        }
    }
    
    override var theme: Theme {
        return Theme.currentTheme(for: ForumID(forum.forumID))
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
        guard let tweaks = ForumTweaks(ForumID(forum.forumID)) else { return }
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
        if enableHaptics {
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
    
    private func presentPollEditor() {
        let editor = PollEditorHostingController(
            poll: poll,
            theme: theme,
            onCancel: { [weak self] in self?.dismiss(animated: true) },
            onSave: { [weak self] poll in
                self?.poll = poll
                self?.dismiss(animated: true)
            }
        )
        // Put the keyboard away first, or it animates out from under the sheet.
        view.endEditing(true)
        present(editor, animated: true)
    }

    @objc private func subjectFieldDidChange(_ sender: UITextField) {
        if let text = sender.text , !text.isEmpty {
            title = text
        } else {
            title = defaultTitle
        }

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            flushDraftAutoSave()
        }
    }

    private func saveDraftNow() {
        draft.subject = fieldView.subjectField.textField.text ?? ""
        draft.threadTag = threadTag
        draft.secondaryThreadTag = secondaryThreadTag
        draft.text = textView.attributedText
        draft.poll = poll
        if draft.subject.isEmpty
            && draft.threadTag == nil
            && draft.secondaryThreadTag == nil
            && (draft.text?.length ?? 0) == 0
            && draft.poll == nil
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
    
    private func updateAvailableThreadTagsIfNecessary() {
        guard availableThreadTags == nil && !updatingThreadTags else { return }
        
        updatingThreadTags = true
        Task {
            do {
                let tags = try await ForumsClient.shared.listAvailablePostIcons(inForumIdentifiedBy: forum.forumID)
                updatingThreadTags = false
                availableThreadTags = tags.primary
                availableSecondaryThreadTags = tags.secondary

                guard let tags = availableThreadTags else { return }
                let secondaryImageNames = availableSecondaryThreadTags?.compactMap { $0.imageName } ?? []
                let picker = ThreadTagPickerViewController(
                    firstTag: .thread(in: forum),
                    imageNames: tags.compactMap { $0.imageName },
                    secondaryImageNames: secondaryImageNames)
                threadTagPicker = picker
                picker.delegate = self
                picker.title = LocalizedString("compose.thread.tag-picker.title")
                if secondaryImageNames.isEmpty {
                    picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
                } else {
                    picker.navigationItem.rightBarButtonItem = picker.doneButtonItem
                }
            } catch {
                updatingThreadTags = false
                availableThreadTags = nil
                availableSecondaryThreadTags = nil
            }
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

        let poll = self.poll.map(\.normalized).flatMap { $0.isValid ? $0 : nil }

        Task {
            let result: ForumsClient.PostNewThreadResult
            do {
                result = try await ForumsClient.shared.postThread(
                    using: formData,
                    subject: subject,
                    threadTag: threadTag,
                    secondaryTag: secondaryThreadTag,
                    bbcode: composition,
                    pollOptionCount: poll?.options.count
                )
            } catch {
                let alert = UIAlertController(title: "Network Error", error: error, handler: {
                    completion(false)
                })
                present(alert, animated: true)
                return
            }

            // Past this point the thread exists on the forums, so there's no going back to the
            // compose screen — retrying would post it a second time.
            self.thread = result.thread
            deleteDraft()

            guard let poll else { return completion(true) }

            do {
                try await postPoll(poll, threadID: result.thread.threadID, form: result.pollForm)
                completion(true)
            } catch {
                presentPollFailure(error, poll: poll, threadID: result.thread.threadID, completion: completion)
            }
        }
    }

    private func postPoll(
        _ poll: PollSubmission,
        threadID: String,
        form: NewPollForm?
    ) async throws {
        // The forums usually hand us the poll form in the response to posting the thread; if they
        // didn't, go and ask for it.
        let pollForm: NewPollForm
        if let form {
            pollForm = form
        } else {
            pollForm = try await ForumsClient.shared.newPollForm(
                threadID: threadID,
                optionCount: poll.options.count
            )
        }
        try await ForumsClient.shared.postPoll(using: pollForm, poll)
    }

    /// The thread is live but its poll isn't. Never offer to go back and edit — that would invite a
    /// duplicate thread — so both ways out of this alert count as a successful submission.
    private func presentPollFailure(
        _ error: Error,
        poll: PollSubmission,
        threadID: String,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: String(localized: "Thread posted, poll wasn't", bundle: .module),
            message: String(
                localized: "Your thread is up, but the poll couldn't be added: \(error.localizedDescription)",
                bundle: .module
            ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: String(localized: "Try Again", bundle: .module),
            style: .default
        ) { [weak self] _ in
            guard let self else { return completion(true) }
            Task {
                do {
                    try await self.postPoll(poll, threadID: threadID, form: nil)
                    completion(true)
                } catch {
                    self.presentPollFailure(error, poll: poll, threadID: threadID, completion: completion)
                }
            }
        })
        alert.addAction(UIAlertAction(
            title: String(localized: "Skip Poll", bundle: .module),
            style: .cancel
        ) { _ in
            completion(true)
        })
        // The preview view controller is on top of us at this point, so present from the navigation
        // controller rather than from a covered-up view controller.
        (navigationController ?? self).present(alert, animated: true)
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
        scheduleDraftAutoSave()

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
        scheduleDraftAutoSave()
    }
    
    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        focusInitialFirstResponder()
    }
}

private let defaultTitle = "New Thread"
