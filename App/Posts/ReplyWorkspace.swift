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

/**
A place for someone to compose a reply to a thread.

ReplyWorkspace conforms to UIStateRestoring, so it is ok to involve it in UIKit state preservation and restoration.
*/
final class ReplyWorkspace: NSObject {
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.confirmBeforeReplying) private var confirmBeforeReplying
    let draft: NSObject & ReplyDraft
    @FoilDefaultStorageOptional(Settings.userID) private var loggedInUserID
    private let restorationIdentifier: String
    
    /**
    Called when the viewController should be dismissed.

    The closure can't be saved as part of UIKit state preservation, so be sure to set something after restoring state.
    */
    var completion: (CompletionResult) -> Void = { _ in }

    enum CompletionResult {
        case forgetAboutIt
        case posted
        case saveDraft
    }
    
    /// Constructs a workspace for a new reply to a thread.
    convenience init(thread: AwfulThread) {
        let draft = NewReplyDraft(thread: thread)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
    }
    
    /// Constructs a workspace for editing a reply.
    convenience init(post: Post, bbcode: String) {
        let draft = EditReplyDraft(post: post)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
        bbcodeForNewlyCreatedCompositionViewController = bbcode
    }
    
    /// A nil restorationIdentifier implies that we were not created by UIKit state restoration.
    fileprivate init(draft: NSObject & ReplyDraft, didRestoreWithRestorationIdentifier restorationIdentifier: String?) {
        self.draft = draft
        self.restorationIdentifier = restorationIdentifier ?? UUID().uuidString
        super.init()
        
        UIApplication.registerObject(forStateRestoration: self, restorationIdentifier: self.restorationIdentifier)
    }
    
    deinit {
        draftTitleObserver?.invalidate()

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

    /*
    Dealing with compositionViewController is annoyingly complicated. Ideally it'd be a constant ivar, so we could either restore state by passing it in via init() or make a new one if we're not restoring state.
    Unfortunately, any compositionViewController that we preserve in encodeRestorableStateWithCoder() is not yet available in objectWithRestorationIdentifierPath(_:coder:); it only becomes available in decodeRestorableStateWithCoder().
    This didSet encompasses the junk we want to set up on the compositionViewController no matter how it's created and really belongs in init(), except we're stuck.
    */
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
                self.rightButtonItem.isEnabled = textView.hasText
            }

            let navigationItem = compositionViewController.navigationItem
            let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(ReplyWorkspace.didTapCancel(_:)))

            // Only set explicit tint color for iOS < 26
            if #available(iOS 26.0, *) {
                // Let iOS 26+ handle the color automatically
            } else {
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

            compositionViewController.setDraft(draft)
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
    
    @IBAction private func didTapCancel(_ sender: UIBarButtonItem) {
        if compositionViewController.textView.attributedText.length == 0 {
            return completion(.forgetAboutIt)
        }

        let title: String
        switch status {
        case let .editing(post) where post.author?.userID == loggedInUserID:
            title = NSLocalizedString("compose.draft-menu.editing-own-post.title", comment: "")
        case let .editing(post):
            if let username = post.author?.username {
                title = String(format: NSLocalizedString("compose.draft-menu.editing-other-post.title", comment: ""), username)
            } else {
                title = NSLocalizedString("compose.draft-menu.editing-unknown-other-post.title", comment: "")
            }
        case .replying:
            title = NSLocalizedString("compose.draft-menu.replying.title", comment: "")
        }

        let actionSheet = UIAlertController(
            title: title,
            actionSheetActions: [
                .destructive(title: NSLocalizedString("compose.cancel-menu.delete-draft", comment: "")) {
                    self.completion(.forgetAboutIt)
                },
                .default(title: NSLocalizedString("compose.cancel-menu.save-draft", comment: "")) {
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
                // Only set explicit tint color for iOS < 26
                if #available(iOS 26.0, *) {
                    // Let iOS 26+ handle the color automatically
                } else {
                    postButton.tintColor = compositionViewController.theme["navigationBarTextColor"]
                }
                preview.navigationItem.rightBarButtonItem = postButton
        (viewController as! UINavigationController).pushViewController(preview, animated: true)
    }
    
    @objc fileprivate func didTapPost(_ sender: UIBarButtonItem) {
        saveTextToDraft()
        
        let progressView = MRProgressOverlayView.showOverlayAdded(to: viewController.view.window, animated: true)
        progressView?.tintColor = viewController.view.tintColor
        progressView?.titleLabelText = draft.progressViewTitle
        
        let submitProgress = draft.submit { [unowned self] error in
            progressView?.dismiss(true)

            if let error = error {
                if (error as? CocoaError)?.code != .userCancelled {
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
                DraftStore.sharedStore().deleteDraft(self.draft)
                
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
    
    fileprivate func saveTextToDraft() {
        draft.text = compositionViewController.textView.attributedText
    }
    
    /// Present this view controller to let someone compose a reply.
    var viewController: UIViewController {
        createCompositionViewController()
        return compositionViewController.enclosingNavigationController
    }
    
    fileprivate func createCompositionViewController() {
        if compositionViewController == nil {
            compositionViewController = CompositionViewController()
            compositionViewController.restorationIdentifier = "\(self.restorationIdentifier) Reply composition"

            if let bbcodeForNewlyCreatedCompositionViewController {
                compositionViewController.textView.text = bbcodeForNewlyCreatedCompositionViewController
                self.bbcodeForNewlyCreatedCompositionViewController = nil
            }
        }
    }
    
    /// Append a quoted post to the reply.
    @MainActor
    func quotePost(_ post: Post) async throws {
        createCompositionViewController()

        let bbcode = try await ForumsClient.shared.quoteBBcodeContents(of: post)
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

extension ReplyWorkspace: UIObjectRestoration, UIStateRestoring {
    var objectRestorationClass: UIObjectRestoration.Type? {
        return ReplyWorkspace.self
    }
    
    func encodeRestorableState(with coder: NSCoder) {
        saveTextToDraft()
        DraftStore.sharedStore().saveDraft(draft)
        coder.encode(draft.storePath, forKey: Keys.draftPath)
        coder.encode(compositionViewController, forKey: Keys.compositionViewController)
    }
    
    class func object(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIStateRestoring? {
        if let path = coder.decodeObject(forKey: Keys.draftPath) as! String? {
            if let draft = DraftStore.sharedStore().loadDraft(path) as! (NSObject & ReplyDraft)? {
                return self.init(draft: draft, didRestoreWithRestorationIdentifier: identifierComponents.last )
            }
        }
        
        logger.error("failing intentionally as no saved draft was found")
        return nil
    }
    
    func decodeRestorableState(with coder: NSCoder) {
        // Our encoded CompositionViewController is not available any earlier (i.e. in objectWithRestorationIdentifierPath(_:coder:)).
        compositionViewController = (coder.decodeObject(forKey: Keys.compositionViewController) as! CompositionViewController)
    }

    fileprivate struct Keys {
        static let draftPath = "draftPath"
        static let compositionViewController = "compositionViewController"
    }
}

@objc protocol ReplyDraft: StorableDraft, SubmittableDraft, ReplyUI {
    var thread: AwfulThread { get }
    var text: NSAttributedString? { get set }
    var title: String { get }
    var forumAttachment: ForumAttachment? { get set }
    var shouldDeleteAttachment: Bool { get set }
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
    var existingAttachmentInfo: (id: String, filename: String)?
    var shouldDeleteAttachment = false

    init(thread: AwfulThread, text: NSAttributedString? = nil) {
        self.thread = thread
        self.text = text
        super.init()
    }

    convenience init?(coder: NSCoder) {
        let threadKey = coder.decodeObject(forKey: Keys.threadKey) as! ThreadKey
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
    }

    let post: Post
    var text: NSAttributedString?
    var forumAttachment: ForumAttachment?
    var existingAttachmentInfo: (id: String, filename: String)?
    var shouldDeleteAttachment = false

    var attachmentAction: AttachmentAction {
        get { shouldDeleteAttachment ? .delete : .keep }
        set { shouldDeleteAttachment = (newValue == .delete) }
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
        let postKey = coder.decodeObject(forKey: Keys.postKey) as! PostKey
        let post = Post.objectForKey(objectKey: postKey, in: AppDelegate.instance.managedObjectContext)
        let text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        self.init(post: post, text: text)

        if let attachmentID = coder.decodeObject(of: NSString.self, forKey: Keys.attachmentID) as? String,
           let attachmentFilename = coder.decodeObject(of: NSString.self, forKey: Keys.attachmentFilename) as? String {
            self.existingAttachmentInfo = (id: attachmentID, filename: attachmentFilename)
        }
        self.shouldDeleteAttachment = coder.decodeBool(forKey: Keys.shouldDeleteAttachment)
    }

    func encode(with coder: NSCoder) {
        coder.encode(post.objectKey, forKey: Keys.postKey)
        coder.encode(text, forKey: Keys.text)
        if let existingAttachmentInfo = existingAttachmentInfo {
            coder.encode(existingAttachmentInfo.id as NSString, forKey: Keys.attachmentID)
            coder.encode(existingAttachmentInfo.filename as NSString, forKey: Keys.attachmentFilename)
        }
        coder.encode(shouldDeleteAttachment, forKey: Keys.shouldDeleteAttachment)
    }

    fileprivate struct Keys {
        static let postKey = "postKey"
        static let text = "text"
        static let attachmentID = "attachmentID"
        static let attachmentFilename = "attachmentFilename"
        static let shouldDeleteAttachment = "shouldDeleteAttachment"
    }
    
    var thread: AwfulThread {
        // TODO can we assume an edited post always has a thread?
        return post.thread!
    }

    var title: String {
        return "Edit: \(thread.title ?? "")"
    }
    
    var storePath: String {
        return "edits/\(post.postID)"
    }
}

extension NewReplyDraft: SubmittableDraft {
    func submit(_ completion: @escaping (Error?) -> Void) -> Progress {
        return uploadImages(attachedTo: text!) { [unowned self] plainText, error in
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
                                let error = NSError(domain: "Awful", code: 0, userInfo: [
                                    NSLocalizedDescriptionKey: self.validationErrorMessage(for: validationError)
                                ])
                                completion(error)
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

    private func validationErrorMessage(for error: ForumAttachment.ValidationError) -> String {
        switch error {
        case .fileTooLarge(let actualSize, let maxSize):
            let actualMB = Double(actualSize) / 1_048_576
            let maxMB = Double(maxSize) / 1_048_576
            return String(format: "Image is too large (%.1f MB). Maximum size is %.1f MB.", actualMB, maxMB)
        case .dimensionsTooLarge(let width, let height, let maxDimension):
            return "Image dimensions (\(width)×\(height)) exceed maximum (\(maxDimension)×\(maxDimension))."
        case .unsupportedFormat:
            return "Unsupported image format. Supported formats: GIF, JPEG, PNG"
        case .imageDataConversionFailed:
            return "Failed to convert image data"
        }
    }
}

extension EditReplyDraft: SubmittableDraft {
    func submit(_ completion: @escaping (Error?) -> Void) -> Progress {
        return uploadImages(attachedTo: text!) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                Task { @MainActor in
                    do {
                        let attachmentAction: ForumsClient.AttachmentAction = shouldDeleteAttachment ? .delete : .keep
                        try await ForumsClient.shared.edit(post, bbcode: plainText ?? "", attachmentAction: attachmentAction)
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
