//  ReplyWorkspace.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import KVOController
import MRProgress

/**
A place for someone to compose a reply to a thread.

ReplyWorkspace conforms to UIStateRestoring, so it is ok to involve it in UIKit state preservation and restoration.
*/
final class ReplyWorkspace: NSObject {
    let draft: ReplyDraft
    private let restorationIdentifier: String
    
    /**
    Called when the viewController should be dismissed. saveDraft is true if the workspace should stick around; newPost is a newly-created Post if one was made.
    
    The closure obviously can't be saved as part of UIKit state preservation, so be sure to set something after restoring state.
    */
    var completion: ((saveDraft: Bool, didSucceed: Bool) -> Void)?
    
    /// Constructs a workspace for a new reply to a thread.
    convenience init(thread: Thread) {
        let draft = NewReplyDraft(thread: thread)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
    }
    
    /// Constructs a workspace for editing a reply.
    convenience init(post: Post) {
        let draft = EditReplyDraft(post: post)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
        
        let progressView = MRProgressOverlayView.showOverlayAddedTo(viewController.view, animated: false)
        progressView.titleLabelText = "Reading post…"
        
        AwfulForumsClient.sharedClient().findBBcodeContentsWithPost(post) { [weak self] error, BBcode in
            progressView.dismiss(true)
            
            if let error = error {
                if self?.compositionViewController.visible == true {
                    let alert = UIAlertController(title: "Couldn't Find BBcode", error: error)
                    self?.viewController.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                self?.compositionViewController.textView.text = BBcode
            }
        }
    }
    
    /// A nil restorationIdentifier implies that we were not created by UIKit state restoration.
    private init(draft: ReplyDraft, didRestoreWithRestorationIdentifier restorationIdentifier: String?) {
        self.draft = draft
        self.restorationIdentifier = restorationIdentifier ?? NSUUID().UUIDString
        super.init()
        
        UIApplication.registerObjectForStateRestoration(self, restorationIdentifier: self.restorationIdentifier)
    }
    
    deinit {
        if let textViewNotificationToken: AnyObject = textViewNotificationToken {
            NSNotificationCenter.defaultCenter().removeObserver(textViewNotificationToken)
        }
    }
    
    /*
    Dealing with compositionViewController is annoyingly complicated. Ideally it'd be a constant ivar, so we could either restore state by passing it in via init() or make a new one if we're not restoring state.
    Unfortunately, any compositionViewController that we preserve in encodeRestorableStateWithCoder() is not yet available in objectWithRestorationIdentifierPath(_:coder:); it only becomes available in decodeRestorableStateWithCoder().
    This didSet encompasses the junk we want to set up on the compositionViewController no matter how it's created and really belongs in init(), except we're stuck.
    */
    private var compositionViewController: CompositionViewController! {
        didSet {
            assert(oldValue == nil, "please set compositionViewController only once")
            
            let textView = compositionViewController.textView
            textView.attributedText = draft.text
            KVOController.observe(draft, keyPath: "thread.title", options: .Initial | .New) { [unowned self] _, _, change in
                self.compositionViewController.title = change[NSKeyValueChangeNewKey] as? String
            }
            
            textViewNotificationToken = NSNotificationCenter.defaultCenter().addObserverForName(UITextViewTextDidChangeNotification, object: compositionViewController.textView, queue: NSOperationQueue.mainQueue()) { [unowned self] note in
                self.rightButtonItem.enabled = textView.hasText()
            }
            
            let navigationItem = compositionViewController.navigationItem
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapCancel:")
            navigationItem.rightBarButtonItem = rightButtonItem
            KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.confirmNewPosts as String, options: .Initial) { [unowned self] _, _, change in
                self.updateRightButtonItem()
            }
            
            if let tweaks = AwfulForumTweaks(forumID: draft.thread.forum?.forumID) {
                textView.autocapitalizationType = tweaks.autocapitalizationType
                textView.autocorrectionType = tweaks.autocorrectionType
                textView.spellCheckingType = tweaks.spellCheckingType
            }
        }
    }
    
    private var textViewNotificationToken: AnyObject?
    
    private lazy var rightButtonItem: UIBarButtonItem = { [unowned self] in
        return UIBarButtonItem(title: self.draft.submitButtonTitle, style: .Done, target: self, action: "didTapPost:")
        }()
    
    private func updateRightButtonItem() {
        if AwfulSettings.sharedSettings().confirmNewPosts {
            rightButtonItem.title = "Preview"
            rightButtonItem.action = "didTapPreview:"
        } else {
            rightButtonItem.title = draft.submitButtonTitle
            rightButtonItem.action = "didTapPost:"
        }
    }
    
    @objc private func didTapCancel(sender: UIBarButtonItem) {
        let saveDraft = compositionViewController.textView.attributedText.length > 0
        completion?(saveDraft: saveDraft, didSucceed: false)
    }
    
    @objc private func didTapPreview(sender: UIBarButtonItem) {
        saveTextToDraft()
        
        let preview = PostPreviewViewController(thread: draft.thread, BBcode: draft.text)
        preview.navigationItem.rightBarButtonItem = UIBarButtonItem(title: draft.submitButtonTitle, style: .Done, target: self, action: "didTapPost:")
        (viewController as! UINavigationController).pushViewController(preview, animated: true)
    }
    
    @objc private func didTapPost(sender: UIBarButtonItem) {
        saveTextToDraft()
        
        let progressView = MRProgressOverlayView.showOverlayAddedTo(viewController.view.window, animated: true)
        progressView.tintColor = viewController.view.tintColor
        progressView.titleLabelText = draft.progressViewTitle
        
        let submitProgress = draft.submit { [unowned self] error in
            progressView.dismiss(true)
            
            if let error = error {
                if !(error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) {
                    let alert = UIAlertController(title: "Image Upload Failed", error: error)
                    self.viewController.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                DraftStore.sharedStore().deleteDraft(self.draft)
                
                self.completion?(saveDraft: false, didSucceed: true)
            }
        }
        self.submitProgress = submitProgress
        
        progressView.stopBlock = { _ in
            submitProgress.cancel() }
        
        KVOController.observe(submitProgress, keyPaths: ["cancelled", "fractionCompleted"], options: nil) { [weak self] _, object, _ in
            if let progress = object as? NSProgress {
                if progress.fractionCompleted >= 1 || progress.cancelled {
                    progressView.stopBlock = nil
                    self?.KVOController.unobserve(progress)
                }
            }
        }
    }
    private var submitProgress: NSProgress?
    
    private func saveTextToDraft() {
        draft.text = compositionViewController.textView.attributedText
    }
    
    /// Present this view controller to let someone compose a reply.
    var viewController: UIViewController {
        createCompositionViewController()
        return compositionViewController.enclosingNavigationController
    }
    
    private func createCompositionViewController() {
        if compositionViewController == nil {
            compositionViewController = CompositionViewController()
            compositionViewController.restorationIdentifier = "\(self.restorationIdentifier) Reply composition"
        }
    }
    
    /// Append a quoted post to the reply.
    func quotePost(post: Post, completion: NSError? -> Void) {
        createCompositionViewController()

        AwfulForumsClient.sharedClient().quoteBBcodeContentsWithPost(post) { [weak self] error, BBcode in
            if let textView = self?.compositionViewController.textView, var replacement = BBcode {
                let selectedRange = textView.selectedTextRange ?? textView.textRangeFromPosition(textView.endOfDocument, toPosition: textView.endOfDocument)!
                
                // Yep. This is just a delight.
                let precedingOffset = max(-2, textView.offsetFromPosition(selectedRange.start, toPosition: textView.beginningOfDocument))
                if precedingOffset < 0 {
                    let precedingStart = textView.positionFromPosition(selectedRange.start, offset: precedingOffset)
                    let precedingRange = textView.textRangeFromPosition(precedingStart, toPosition: selectedRange.start)
                    let preceding = textView.textInRange(precedingRange)
                    if preceding != "\n\n" {
                        if preceding.hasSuffix("\n") {
                            replacement = "\n" + replacement
                        } else {
                            replacement = "\n\n" + replacement
                        }
                    }
                }
                
                textView.replaceRange(selectedRange, withText: replacement)
            }
            
            completion(error)
        }
    }
}

extension ReplyWorkspace: UIObjectRestoration, UIStateRestoring {
    var objectRestorationClass: AnyObject.Type {
        return ReplyWorkspace.self
    }
    
    func encodeRestorableStateWithCoder(coder: NSCoder) {
        saveTextToDraft()
        DraftStore.sharedStore().saveDraft(draft)
        coder.encodeObject(draft.storePath, forKey: Keys.draftPath)
        coder.encodeObject(compositionViewController, forKey: Keys.compositionViewController)
    }
    
    class func objectWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIStateRestoring? {
        if let path = coder.decodeObjectForKey(Keys.draftPath) as! String? {
            if let draft = DraftStore.sharedStore().loadDraft(path) as! ReplyDraft? {
                return self(draft: draft, didRestoreWithRestorationIdentifier: identifierComponents.last as! String?)
            }
        }
        
        NSLog("[%@ %@] failing intentionally as no saved draft was found", self.description(), __FUNCTION__)
        return nil
    }
    
    func decodeRestorableStateWithCoder(coder: NSCoder!) {
        // Our encoded CompositionViewController is not available any earlier (i.e. in objectWithRestorationIdentifierPath(_:coder:)).
        compositionViewController = coder.decodeObjectForKey(Keys.compositionViewController) as! CompositionViewController
    }

    private struct Keys {
        static let draftPath = "draftPath"
        static let compositionViewController = "compositionViewController"
    }
}

@objc protocol ReplyDraft: StorableDraft, SubmittableDraft, ReplyUI {
    var thread: Thread { get }
    var text: NSAttributedString? { get set }
}

@objc protocol SubmittableDraft {
    func submit(completion: NSError? -> Void) -> NSProgress
}

@objc protocol ReplyUI {
    var submitButtonTitle: String { get }
    var progressViewTitle: String { get }
}

final class NewReplyDraft: NSObject, ReplyDraft {
    let thread: Thread
    var text: NSAttributedString?
    
    init(thread: Thread, text: NSAttributedString? = nil) {
        self.thread = thread
        self.text = text
        super.init()
    }
    
    convenience init(coder: NSCoder) {
        let threadKey = coder.decodeObjectForKey(Keys.threadKey) as! ThreadKey
        let thread = Thread.objectForKey(threadKey, inManagedObjectContext: AwfulAppDelegate.instance().managedObjectContext) as! Thread
        let text = coder.decodeObjectForKey(Keys.text) as? NSAttributedString
        self.init(thread: thread, text: text)
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(thread.objectKey, forKey: Keys.threadKey)
        coder.encodeObject(text, forKey: Keys.text)
    }
    
    private struct Keys {
        static let threadKey = "threadKey"
        static let text = "text"
    }
    
    var storePath: String {
        return "replies/\(thread.threadID)"
    }
}

final class EditReplyDraft: NSObject, ReplyDraft {
    let post: Post
    var text: NSAttributedString?
    
    init(post: Post, text: NSAttributedString? = nil) {
        self.post = post
        self.text = text
        super.init()
    }
    
    convenience init(coder: NSCoder) {
        let postKey = coder.decodeObjectForKey(Keys.postKey) as! PostKey
        let post = Post.objectForKey(postKey, inManagedObjectContext: AwfulAppDelegate.instance().managedObjectContext) as! Post
        let text = coder.decodeObjectForKey(Keys.text) as? NSAttributedString
        self.init(post: post, text: text)
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(post.objectKey, forKey: Keys.postKey)
        coder.encodeObject(text, forKey: Keys.text)
    }
    
    private struct Keys {
        static let postKey = "postKey"
        static let text = "text"
    }
    
    var thread: Thread {
        // TODO can we assume an edited post always has a thread?
        return post.thread!
    }
    
    var storePath: String {
        return "edits/\(post.postID)"
    }
}

extension NewReplyDraft: SubmittableDraft {
    func submit(completion: NSError? -> Void) -> NSProgress {
        return UploadImageAttachments(text!) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                AwfulForumsClient.sharedClient().replyToThread(self.thread, withBBcode: plainText) { error, post in
                    completion(error)
                }
            }
        }
    }
}

extension EditReplyDraft: SubmittableDraft {
    func submit(completion: NSError? -> Void) -> NSProgress {
        return UploadImageAttachments(text!) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                AwfulForumsClient.sharedClient().editPost(self.post, setBBcode: plainText, andThen: completion)
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
