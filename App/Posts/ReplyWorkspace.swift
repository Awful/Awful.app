//  ReplyWorkspace.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import Combine
import MRProgress
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ReplyWorkspace")

/// A place for someone to compose a reply to a thread.
final class ReplyWorkspace: NSObject {
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.confirmBeforeReplying) private var confirmBeforeReplying
    let draft: NSObject & ReplyDraft
    /// Called when the viewController should be dismissed.
    var completion: (CompletionResult) -> Void = { _ in }

    /// Called after the user swipes the compose sheet away with a non-empty draft (which keeps the
    /// workspace and its draft alive), so the owner can surface a minimized-draft affordance. An
    /// empty draft reports `completion(.forgetAboutIt)` instead.
    var onInteractiveDismiss: (() -> Void)?

    enum CompletionResult {
        case forgetAboutIt
        case posted
        case saveDraft
    }

    /// Constructs a workspace for a new reply to a thread, loading any saved draft from disk.
    convenience init(thread: AwfulThread) {
        let saved = DraftStore.sharedStore().loadDraft("replies/\(thread.threadID)") as? NewReplyDraft
        let draft: NewReplyDraft
        if let saved, saved.thread.threadID == thread.threadID {
            draft = saved
        } else if let saved {
            // An archive under this thread's path decoded a different thread; the path is the
            // trustworthy signal, so keep the text but bind it to the tapped thread. The next
            // auto-save overwrites the bad archive at the same path.
            logger.error("saved reply draft at replies/\(thread.threadID) decoded thread \(saved.thread.threadID); re-binding to the tapped thread")
            draft = NewReplyDraft(thread: thread, text: saved.text)
            draft.forumAttachment = saved.forumAttachment
        } else {
            draft = NewReplyDraft(thread: thread)
        }
        self.init(draft: draft)
    }

    /// Constructs a workspace for editing a reply. A saved edit draft from disk takes the place of
    /// the post's current contents only when the two actually differ; check
    /// `restoredSavedEditDraft` and give the user the choice before presenting, since the draft may
    /// be stale.
    convenience init(post: Post, bbcode: String) {
        // The scraped textarea uses \r\n line endings while the text view uses \n, so normalize
        // before deciding whether the draft differs.
        func normalized(_ s: String) -> String { s.replacingOccurrences(of: "\r\n", with: "\n") }
        if let saved = DraftStore.sharedStore().loadDraft("edits/\(post.postID)") as? EditReplyDraft,
           saved.post.postID == post.postID,
           let savedText = saved.text?.string,
           !savedText.isEmpty,
           normalized(savedText) != normalized(bbcode)
        {
            self.init(draft: saved)
            restoredSavedEditDraft = true
        } else {
            self.init(draft: EditReplyDraft(post: post))
            bbcodeForNewlyCreatedCompositionViewController = bbcode
        }
    }

    /// `true` when this workspace holds a saved edit draft instead of the post's current
    /// server-side contents.
    private(set) var restoredSavedEditDraft = false

    private init(draft: NSObject & ReplyDraft) {
        self.draft = draft
        super.init()
    }

    deinit {
        draftTitleObserver?.invalidate()
        autoSaveWorkItem?.cancel()

        if let textViewNotificationToken = textViewNotificationToken {
            NotificationCenter.default.removeObserver(textViewNotificationToken)
        }
    }

    var status: Status {
        switch draft {
        case let draft as EditReplyDraft:
            return .editing(draft.post)
        case is NewReplyDraft:
            return .replying
        case let draft:
            assertionFailure("Unexpected reply type \(draft)")
            return .replying
        }
    }

    enum Status {
        case editing(Post)
        case replying
    }

    private var draftTitleObserver: NSKeyValueObservation?
    
    // compositionViewController isn't available at init time, but sometimes we already know the bbcode.
    private var bbcodeForNewlyCreatedCompositionViewController: String?

    var compositionViewController: CompositionViewController! {
        didSet {
            assert(oldValue == nil, "please set compositionViewController only once")

            // Ensure the view is loaded before accessing textView
            compositionViewController.loadViewIfNeeded()

            let textView = compositionViewController.textView
            textView.attributedText = draft.text

            let changeHandler: (ReplyDraft) -> Void = { [weak self] draft in
                self?.compositionViewController.title = draft.title
            }
            switch draft {
            case let draft as NewReplyDraft:
                draftTitleObserver = draft.observe(\.thread.title, options: [.initial]) { draft, change in changeHandler(draft) }
            case let draft as EditReplyDraft:
                draftTitleObserver = draft.observe(\.thread.title, options: [.initial]) { draft, change in changeHandler(draft) }
            case let unknown:
                fatalError("unexpected draft type \(type(of: unknown))")
            }

            textViewNotificationToken = NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification, object: compositionViewController.textView, queue: OperationQueue.main) { [unowned self] note in
                self.rightButtonItem.isEnabled = textView.hasText && !self.isSubmitting
                self.scheduleDraftAutoSave()
            }

            let navigationItem = compositionViewController.navigationItem
            let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(ReplyWorkspace.didTapCancel(_:)))
            // Liquid Glass handles the color automatically; otherwise tint explicitly.
            if !LiquidGlass.isEnabled {
                cancelButton.tintColor = compositionViewController.theme["navigationBarTextColor"]
            }
            navigationItem.leftBarButtonItem = cancelButton
            navigationItem.rightBarButtonItem = rightButtonItem

            $confirmBeforeReplying
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateRightButtonItem() }
                .store(in: &cancellables)

            if let forumID = draft.thread.forum?.forumID,
               let tweaks = ForumTweaks(ForumID(forumID))
            {
                textView.autocapitalizationType = tweaks.autocapitalizationType
                textView.autocorrectionType = tweaks.autocorrectionType
                textView.spellCheckingType = tweaks.spellCheckingType
            }

            compositionViewController.onAttachmentProcessingChanged = { [weak self] isProcessing in
                self?.rightButtonItem.isEnabled = !isProcessing && !(self?.isSubmitting ?? false)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.compositionViewController.setDraft(self.draft)
            }
        }
    }
    
    fileprivate var textViewNotificationToken: AnyObject?
    
    fileprivate lazy var rightButtonItem: UIBarButtonItem = { [unowned self] in
        return UIBarButtonItem(title: self.draft.submitButtonTitle, style: .plain, target: self, action: #selector(ReplyWorkspace.didTapPost(_:)))
        }()
    
    fileprivate func updateRightButtonItem() {
        if confirmBeforeReplying {
            rightButtonItem.title = "Preview"
            rightButtonItem.action = #selector(ReplyWorkspace.didTapPreview(_:))
        } else {
            rightButtonItem.title = draft.submitButtonTitle
            rightButtonItem.action = #selector(ReplyWorkspace.didTapPost(_:))
        }
    }
    
    private var draftMenuTitle: String {
        "Keep draft for \(draft.thread.title ?? "")?"
    }

    @IBAction private func didTapCancel(_ sender: UIBarButtonItem) {
        if compositionViewController.textView.attributedText.length == 0 {
            forgetDraft()
            return completion(.forgetAboutIt)
        }

        let actionSheet = UIAlertController(
            title: draftMenuTitle,
            actionSheetActions: [
                .destructive(title: NSLocalizedString("compose.cancel-menu.delete-draft", comment: "")) {
                    self.forgetDraft()
                    self.completion(.forgetAboutIt)
                },
                .default(title: NSLocalizedString("compose.cancel-menu.save-draft", comment: "")) {
                    self.flushDraftAutoSave()
                    self.completion(.saveDraft)
                },
                .cancel(),
            ]
        )
        compositionViewController.present(actionSheet, animated: true)

        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    @objc fileprivate func didTapPreview(_ sender: UIBarButtonItem) {
        saveTextToDraft()
        
        let preview: PostPreviewViewController
        if let edit = draft as? EditReplyDraft {
            preview = PostPreviewViewController(post: edit.post, BBcode: draft.text ?? .init())
        } else {
            preview = PostPreviewViewController(thread: draft.thread, BBcode: draft.text ?? .init())
        }
        let postButton = UIBarButtonItem(title: draft.submitButtonTitle, style: .plain, target: self, action: #selector(ReplyWorkspace.didTapPost(_:)))
        // Liquid Glass handles the color automatically; otherwise tint explicitly.
        if !LiquidGlass.isEnabled {
            postButton.tintColor = compositionViewController.theme["navigationBarTextColor"]
        }
        preview.navigationItem.rightBarButtonItem = postButton
        (viewController as! UINavigationController).pushViewController(preview, animated: true)
    }
    
    @objc fileprivate func didTapPost(_ sender: UIBarButtonItem) {
        guard !isSubmitting else { return }
        isSubmitting = true
        sender.isEnabled = false
        rightButtonItem.isEnabled = false
        saveTextToDraft()

        let progressView = MRProgressOverlayView.showOverlayAdded(to: viewController.view.window, animated: true)
        progressView?.tintColor = viewController.view.tintColor
        progressView?.titleLabelText = draft.progressViewTitle

        let submitProgress = draft.submit { [unowned self] error in
            progressView?.dismiss(true)
            self.isSubmitting = false

            if let error = error {
                sender.isEnabled = true
                self.rightButtonItem.isEnabled = self.compositionViewController.textView.hasText
                if (error as? CocoaError)?.code != .userCancelled {
                    if case ImageUploadError.authenticationRequired = error {
                        let alert = UIAlertController(
                            title: error.localizedDescription,
                            message: (error as? LocalizedError)?.failureReason ?? "You need to log in to Imgur to upload images with your account.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Log In", style: .default) { _ in
                            ImgurAuthManager.shared.authenticate(from: self.viewController) { success in
                                DispatchQueue.main.async {
                                    if success {
                                        self.didTapPost(sender)
                                    } else {
                                        let failureAlert = UIAlertController(
                                            title: "Authentication Failed",
                                            message: "Could not log in to Imgur. You can try again or switch to anonymous uploads in settings.",
                                            alertActions: [.ok()]
                                        )
                                        self.viewController.present(failureAlert, animated: true)
                                    }
                                }
                            }
                        })
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        self.viewController.present(alert, animated: true)
                        return
                    }

                    let alert: UIAlertController
                    switch error {
                    case let error as LocalizedError where error.failureReason != nil:
                        alert = UIAlertController(title: error.localizedDescription, message: error.failureReason ?? "", alertActions: [.ok()])

                    case let error as LocalizedError:
                        alert = UIAlertController(title: LocalizedString("image-upload.generic-error-title"), message: error.localizedDescription, alertActions: [.ok()])

                    case let error:
                        alert = UIAlertController(title: LocalizedString("image-upload.generic-error-title"), error: error)
                    }
                    self.viewController.present(alert, animated: true)
                }
            } else {
                self.forgetDraft()

                self.completion(.posted)
            }
        }
        self.submitProgress = submitProgress

        progressView?.stopBlock = { _ in
            submitProgress.cancel() }

        var progressObservations: [NSKeyValueObservation] = []
        let changeHandler: (Progress) -> Void = { progress in
            DispatchQueue.main.async {
                if progress.fractionCompleted >= 1 || progress.isCancelled {
                    progressView?.stopBlock = nil
                    progressObservations.forEach { $0.invalidate() }
                    progressObservations.removeAll()
                }
            }
        }
        progressObservations.append(submitProgress.observe(\.isCancelled, options: []) { progress, change in
            changeHandler(progress)
        })
        progressObservations.append(submitProgress.observe(\.fractionCompleted, options: []) { progress, change in
            changeHandler(progress)
        })
    }
    fileprivate var submitProgress: Progress?

    /// Guards against re-entrant submission (e.g. a second tap before the progress overlay
    /// appears, or a tap from the preview screen's own Post button).
    fileprivate var isSubmitting = false
    
    fileprivate func saveTextToDraft() {
        draft.text = compositionViewController.textView.attributedText
    }

    /// Deletes the on-disk draft and cancels any pending auto-save.
    func forgetDraft() {
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        DraftStore.sharedStore().deleteDraft(draft)
    }

    private var autoSaveWorkItem: DispatchWorkItem?

    /// Debounced auto-save: copies the text view's contents into the in-memory draft and writes
    /// the draft to disk so it can be recovered on next launch (or next Reply tap on the same
    /// thread). If the user has cleared everything, deletes the draft instead.
    private func scheduleDraftAutoSave() {
        autoSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performDraftAutoSave() }
        autoSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Synchronously runs the pending auto-save. Called on dismissal paths where the 0.5 s
    /// debounce might otherwise drop the user's most recent edits.
    private func flushDraftAutoSave() {
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        performDraftAutoSave()
    }

    private func performDraftAutoSave() {
        saveTextToDraft()
        if compositionViewController.textView.attributedText.length == 0 {
            DraftStore.sharedStore().deleteDraft(draft)
        } else {
            DraftStore.sharedStore().saveDraft(draft)
        }
    }
    
    /// Present this view controller to let someone compose a reply.
    var viewController: UIViewController {
        createCompositionViewController()
        let nav = compositionViewController.enclosingNavigationController
        nav.presentationController?.delegate = self
        return nav
    }
    
    fileprivate func createCompositionViewController() {
        if compositionViewController == nil {
            compositionViewController = CompositionViewController()

            if let bbcodeForNewlyCreatedCompositionViewController {
                compositionViewController.textView.text = bbcodeForNewlyCreatedCompositionViewController
                self.bbcodeForNewlyCreatedCompositionViewController = nil
            }
        }
    }
    
    /// Called when the posts page that owns this workspace is leaving while a draft sits minimized.
    /// Prompts (from `presenter`, whatever is on screen now) to keep or delete the draft; an empty
    /// draft is quietly deleted, and a draft the user never opened this visit is quietly kept.
    func promptToKeepDraft(from presenter: UIViewController) {
        guard let compositionViewController else { return }

        if compositionViewController.textView.attributedText.length == 0 {
            forgetDraft()
            return
        }

        // Persist the latest text first so nothing is lost if the app exits before the user picks.
        flushDraftAutoSave()

        // Capturing self strongly is the point: the posts page that owned this workspace is gone,
        // so the alert keeps the workspace alive until the user decides.
        let alert = UIAlertController(
            title: draftMenuTitle,
            alertActions: [
                .destructive(title: NSLocalizedString("compose.cancel-menu.delete-draft", comment: "")) {
                    self.forgetDraft()
                },
                .default(title: NSLocalizedString("compose.cancel-menu.save-draft", comment: "")),
            ]
        )
        presenter.present(alert, animated: true)
    }

    /// Append a quoted post to the reply.
    @MainActor
    func quotePost(_ post: Post) async throws {
        createCompositionViewController()

        let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: post)

        // The composition text view is live while we're fetching; if the quote is no longer wanted
        // (workspace replaced, reply posted, posts page gone), don't splice it into whatever the
        // user is typing now.
        try Task.checkCancellation()

        let textView = compositionViewController.textView
        var replacement = bbcode
        let selectedRange = textView.selectedTextRange ?? textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument)!

        // Yep. This is just a delight.
        let precedingOffset = max(-2, textView.offset(from: selectedRange.start, to: textView.beginningOfDocument))
        if
            precedingOffset < 0,
            let precedingStart = textView.position(from: selectedRange.start, offset: precedingOffset),
            let precedingRange = textView.textRange(from: precedingStart, to: selectedRange.start),
            let preceding = textView.text(in: precedingRange),
            preceding != "\n\n"
        {
            if preceding.hasSuffix("\n") {
                replacement = "\n" + replacement
            } else {
                replacement = "\n\n" + replacement
            }
        }

        textView.replaceSelection(with: replacement)
    }
}

extension ReplyWorkspace: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Swiping the sheet away skips the Cancel flow entirely, so make sure the on-disk draft
        // matches what was in the text view (or is deleted, if the text view was emptied).
        flushDraftAutoSave()

        if compositionViewController.textView.attributedText.length > 0 {
            onInteractiveDismiss?()
        } else {
            completion(.forgetAboutIt)
        }
    }
}

@objc protocol ReplyDraft: StorableDraft, SubmittableDraft, ReplyUI {
    var thread: AwfulThread { get }
    var text: NSAttributedString? { get set }
    var title: String { get }
    var forumAttachment: ForumAttachment? { get set }
}

@objc protocol SubmittableDraft {
    func submit(_ completion: @escaping (Error?) -> Void) -> Progress
}

@objc protocol ReplyUI {
    var submitButtonTitle: String { get }
    var progressViewTitle: String { get }
}

final class NewReplyDraft: NSObject, ReplyDraft {
    let thread: AwfulThread
    var text: NSAttributedString?
    var forumAttachment: ForumAttachment?

    init(thread: AwfulThread, text: NSAttributedString? = nil) {
        self.thread = thread
        self.text = text
        super.init()
    }

    convenience init?(coder: NSCoder) {
        guard let threadKey = coder.decodeObject(forKey: Keys.threadKey) as? ThreadKey else { return nil }
        let thread = AwfulThread.objectForKey(objectKey: threadKey, in: AppDelegate.instance.managedObjectContext)
        let text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        self.init(thread: thread, text: text)
        self.forumAttachment = coder.decodeObject(of: ForumAttachment.self, forKey: Keys.forumAttachment)
    }

    func encode(with coder: NSCoder) {
        coder.encode(thread.objectKey, forKey: Keys.threadKey)
        coder.encode(text, forKey: Keys.text)
        if let forumAttachment = forumAttachment {
            coder.encode(forumAttachment, forKey: Keys.forumAttachment)
        }
    }

    fileprivate struct Keys {
        static let threadKey = "threadKey"
        static let text = "text"
        static let forumAttachment = "forumAttachment"
    }
    
    var storePath: String {
        return "replies/\(thread.threadID)"
    }

    var title: String {
        return "Re: \(thread.title ?? "")"
    }
}

final class EditReplyDraft: NSObject, ReplyDraft {
    enum AttachmentAction {
        case keep
        case delete
        case replace
    }

    let post: Post
    var text: NSAttributedString?
    var forumAttachment: ForumAttachment?
    var existingAttachmentInfo: (id: String, filename: String)?
    var existingAttachmentImage: UIImage?
    var shouldDeleteAttachment = false
    /// Whether the server's edit form supports attachment uploads for this post.
    var canAddAttachment = false

    var attachmentAction: AttachmentAction {
        get {
            if forumAttachment != nil {
                return .replace
            }
            return shouldDeleteAttachment ? .delete : .keep
        }
        set {
            switch newValue {
            case .keep:
                shouldDeleteAttachment = false
                forumAttachment = nil
            case .delete:
                shouldDeleteAttachment = true
                forumAttachment = nil
            case .replace:
                shouldDeleteAttachment = true
            }
        }
    }

    var existingAttachmentFilename: String? {
        return existingAttachmentInfo?.filename
    }

    var existingAttachmentFilesize: String? {
        // We don't have filesize info from the server, so return nil
        return nil
    }

    init(post: Post, text: NSAttributedString? = nil) {
        self.post = post
        self.text = text
        super.init()
    }

    convenience init?(coder: NSCoder) {
        guard let postKey = coder.decodeObject(forKey: Keys.postKey) as? PostKey else { return nil }
        let post = Post.objectForKey(objectKey: postKey, in: AppDelegate.instance.managedObjectContext)
        let text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        self.init(post: post, text: text)

        if let attachmentID = coder.decodeObject(of: NSString.self, forKey: Keys.attachmentID) as? String,
           let attachmentFilename = coder.decodeObject(of: NSString.self, forKey: Keys.attachmentFilename) as? String {
            self.existingAttachmentInfo = (id: attachmentID, filename: attachmentFilename)
        }
        if let imageData = coder.decodeObject(of: NSData.self, forKey: Keys.attachmentImageData) as? Data {
            self.existingAttachmentImage = UIImage(data: imageData)
        }
        self.shouldDeleteAttachment = coder.decodeBool(forKey: Keys.shouldDeleteAttachment)
        self.forumAttachment = coder.decodeObject(of: ForumAttachment.self, forKey: Keys.forumAttachment)
    }

    func encode(with coder: NSCoder) {
        coder.encode(post.objectKey, forKey: Keys.postKey)
        coder.encode(text, forKey: Keys.text)
        if let existingAttachmentInfo = existingAttachmentInfo {
            coder.encode(existingAttachmentInfo.id as NSString, forKey: Keys.attachmentID)
            coder.encode(existingAttachmentInfo.filename as NSString, forKey: Keys.attachmentFilename)
        }
        if let imageData = existingAttachmentImage?.pngData() {
            coder.encode(imageData as NSData, forKey: Keys.attachmentImageData)
        }
        coder.encode(shouldDeleteAttachment, forKey: Keys.shouldDeleteAttachment)
        if let forumAttachment = forumAttachment {
            coder.encode(forumAttachment, forKey: Keys.forumAttachment)
        }
    }

    fileprivate struct Keys {
        static let postKey = "postKey"
        static let text = "text"
        static let attachmentID = "attachmentID"
        static let attachmentFilename = "attachmentFilename"
        static let attachmentImageData = "attachmentImageData"
        static let shouldDeleteAttachment = "shouldDeleteAttachment"
        static let forumAttachment = "forumAttachment"
    }
    
    var thread: AwfulThread {
        guard let thread = post.thread else {
            fatalError("EditReplyDraft requires post to have an associated thread")
        }
        return thread
    }

    var title: String {
        return "Edit: \(thread.title ?? "")"
    }
    
    var storePath: String {
        return "edits/\(post.postID)"
    }
}

extension NewReplyDraft: SubmittableDraft {
    enum SubmissionError: LocalizedError {
        case emptyText
        case attachmentValidationFailed(ForumAttachment.ValidationError)

        var errorDescription: String? {
            switch self {
            case .emptyText:
                return "Post text cannot be empty"
            case .attachmentValidationFailed(let validationError):
                return validationError.localizedDescription
            }
        }
    }

    func submit(_ completion: @escaping (Error?) -> Void) -> Progress {
        guard let text = text else {
            completion(SubmissionError.emptyText)
            return Progress(totalUnitCount: 1)
        }

        return uploadImages(attachedTo: text) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                Task { @MainActor in
                    do {
                        var attachmentData: (data: Data, filename: String, mimeType: String)?
                        if let forumAttachment = forumAttachment {
                            let limits = try await ForumsClient.shared.fetchAttachmentLimits(for: thread)

                            if let validationError = forumAttachment.validate(
                                maxFileSize: limits.maxFileSize,
                                maxDimension: limits.maxDimension
                            ) {
                                completion(SubmissionError.attachmentValidationFailed(validationError))
                                return
                            }
                            attachmentData = try forumAttachment.imageData()
                        }

                        _ = try await ForumsClient.shared.reply(to: thread, bbcode: plainText ?? "", attachment: attachmentData)
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                }
            }
        }
    }
}

extension EditReplyDraft: SubmittableDraft {
    enum SubmissionError: LocalizedError {
        case emptyText
        case attachmentValidationFailed(ForumAttachment.ValidationError)

        var errorDescription: String? {
            switch self {
            case .emptyText:
                return "Post text cannot be empty"
            case .attachmentValidationFailed(let validationError):
                return validationError.localizedDescription
            }
        }
    }

    func submit(_ completion: @escaping (Error?) -> Void) -> Progress {
        guard let text = text else {
            completion(SubmissionError.emptyText)
            return Progress(totalUnitCount: 1)
        }

        return uploadImages(attachedTo: text) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                Task { @MainActor in
                    do {
                        let clientAction: ForumsClient.AttachmentAction

                        if let newAttachment = forumAttachment {
                            // Uploading a new attachment (replace existing or add to post without one)
                            let limits = try await ForumsClient.shared.fetchAttachmentLimits(for: thread)

                            if let validationError = newAttachment.validate(
                                maxFileSize: limits.maxFileSize,
                                maxDimension: limits.maxDimension
                            ) {
                                completion(SubmissionError.attachmentValidationFailed(validationError))
                                return
                            }
                            let imageData = try newAttachment.imageData()
                            clientAction = .upload(data: imageData.data, filename: imageData.filename, mimeType: imageData.mimeType)
                        } else if shouldDeleteAttachment {
                            clientAction = .delete
                        } else {
                            clientAction = .keep
                        }

                        try await ForumsClient.shared.edit(post, bbcode: plainText ?? "", attachmentAction: clientAction)
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                }
            }
        }
    }
}

extension NewReplyDraft: ReplyUI {
    var submitButtonTitle: String {
        return "Post"
    }
    
    var progressViewTitle: String {
        return "Posting…"
    }
}

extension EditReplyDraft: ReplyUI {
    var submitButtonTitle: String {
        return "Save"
    }
    
    var progressViewTitle: String {
        return "Saving…"
    }
}
