//  ReplyWorkspace.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import KVOController
import MRProgress

/**
A place for someone to compose a reply to a thread.

ReplyWorkspace conforms to UIStateRestoring, so it is ok to involve it in UIKit state preservation and restoration.
*/
final class ReplyWorkspace: NSObject {
    let draft: ReplyDraft
    fileprivate let restorationIdentifier: String
    
    /**
    Called when the viewController should be dismissed. saveDraft is true if the workspace should stick around; newPost is a newly-created Post if one was made.
    
    The closure obviously can't be saved as part of UIKit state preservation, so be sure to set something after restoring state.
    */
    var completion: ((_ saveDraft: Bool, _ didSucceed: Bool) -> Void)?
    
    /// Constructs a workspace for a new reply to a thread.
    convenience init(thread: AwfulThread) {
        let draft = NewReplyDraft(thread: thread)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
    }
    
    /// Constructs a workspace for editing a reply.
    convenience init(post: Post) {
        let draft = EditReplyDraft(post: post)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
        
        let progressView = MRProgressOverlayView.showOverlayAdded(to: viewController.view, animated: false)
        progressView?.titleLabelText = "Reading post…"
        
        _ = AwfulForumsClient.shared().findBBcodeContents(with: post) { [weak self] (error: Error?, BBcode: String?) in
            progressView?.dismiss(true)
            
            if let error = error {
                if self?.compositionViewController.visible == true {
                    let alert = UIAlertController(title: "Couldn't Find BBcode", error: error)
                    self?.viewController.present(alert, animated: true, completion: nil)
                }
            } else {
                self?.compositionViewController.textView.text = BBcode
            }
        }
    }
    
    /// A nil restorationIdentifier implies that we were not created by UIKit state restoration.
    fileprivate init(draft: ReplyDraft, didRestoreWithRestorationIdentifier restorationIdentifier: String?) {
        self.draft = draft
        self.restorationIdentifier = restorationIdentifier ?? UUID().uuidString
        super.init()
        
        UIApplication.registerObject(forStateRestoration: self, restorationIdentifier: self.restorationIdentifier)
    }
    
    deinit {
        if let textViewNotificationToken: AnyObject = textViewNotificationToken {
            NotificationCenter.default.removeObserver(textViewNotificationToken)
        }
    }
    
    /*
    Dealing with compositionViewController is annoyingly complicated. Ideally it'd be a constant ivar, so we could either restore state by passing it in via init() or make a new one if we're not restoring state.
    Unfortunately, any compositionViewController that we preserve in encodeRestorableStateWithCoder() is not yet available in objectWithRestorationIdentifierPath(_:coder:); it only becomes available in decodeRestorableStateWithCoder().
    This didSet encompasses the junk we want to set up on the compositionViewController no matter how it's created and really belongs in init(), except we're stuck.
    */
    fileprivate var compositionViewController: CompositionViewController! {
        didSet {
            assert(oldValue == nil, "please set compositionViewController only once")
            
            let textView = compositionViewController.textView
            textView.attributedText = draft.text
            kvoController.observe(draft, keyPath: "thread.title", options: [.initial, .new]) { [unowned self] _, _, change in
                self.compositionViewController.title = change?[NSKeyValueChangeKey.newKey.rawValue] as? String
            }
            
            textViewNotificationToken = NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextViewTextDidChange, object: compositionViewController.textView, queue: OperationQueue.main) { [unowned self] note in
                self.rightButtonItem.isEnabled = textView.hasText
            }
            
            let navigationItem = compositionViewController.navigationItem
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(ReplyWorkspace.didTapCancel(_:)))
            navigationItem.rightBarButtonItem = rightButtonItem
            kvoController.observe(AwfulSettings.shared(), keyPath: AwfulSettingsKeys.confirmNewPosts.takeUnretainedValue() as String, options: .initial) { [unowned self] _, _, change in
                self.updateRightButtonItem()
            }
            
            if let
                forumID = draft.thread.forum?.forumID,
                let tweaks = ForumTweaks(forumID: forumID)
            {
                textView.autocapitalizationType = tweaks.autocapitalizationType
                textView.autocorrectionType = tweaks.autocorrectionType
                textView.spellCheckingType = tweaks.spellCheckingType
            }
        }
    }
    
    fileprivate var textViewNotificationToken: AnyObject?
    
    fileprivate lazy var rightButtonItem: UIBarButtonItem = { [unowned self] in
        return UIBarButtonItem(title: self.draft.submitButtonTitle, style: .done, target: self, action: #selector(ReplyWorkspace.didTapPost(_:)))
        }()
    
    fileprivate func updateRightButtonItem() {
        if AwfulSettings.shared().confirmNewPosts {
            rightButtonItem.title = "Preview"
            rightButtonItem.action = #selector(ReplyWorkspace.didTapPreview(_:))
        } else {
            rightButtonItem.title = draft.submitButtonTitle
            rightButtonItem.action = #selector(ReplyWorkspace.didTapPost(_:))
        }
    }
    
    @objc fileprivate func didTapCancel(_ sender: UIBarButtonItem) {
        let saveDraft = compositionViewController.textView.attributedText.length > 0
        completion?(saveDraft, false)
    }
    
    @objc fileprivate func didTapPreview(_ sender: UIBarButtonItem) {
        saveTextToDraft()
        
        let preview = PostPreviewViewController(thread: draft.thread, BBcode: draft.text ?? NSAttributedString())
        preview.navigationItem.rightBarButtonItem = UIBarButtonItem(title: draft.submitButtonTitle, style: .done, target: self, action: #selector(ReplyWorkspace.didTapPost(_:)))
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
                if !((error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError) {
                    let alert = UIAlertController(title: "Image Upload Failed", error: error)
                    self.viewController.present(alert, animated: true, completion: nil)
                }
            } else {
                DraftStore.sharedStore().deleteDraft(self.draft)
                
                self.completion?(false, true)
            }
        }
        self.submitProgress = submitProgress
        
        progressView?.stopBlock = { _ in
            submitProgress.cancel() }
        
        kvoController.observe(submitProgress, keyPaths: ["cancelled", "fractionCompleted"], options: []) { [weak self] _, object, _ in
            if let progress = object as? Progress {
                if progress.fractionCompleted >= 1 || progress.isCancelled {
                    progressView?.stopBlock = nil
                    self?.kvoController.unobserve(progress)
                }
            }
        }
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
        }
    }
    
    /// Append a quoted post to the reply.
    func quotePost(_ post: Post, completion: @escaping (Error?) -> Void) {
        createCompositionViewController()

        AwfulForumsClient.shared().quoteBBcodeContents(with: post) { [weak self] (error: Error?, BBcode: String?) in
            if let textView = self?.compositionViewController.textView, var replacement = BBcode {
                let selectedRange = textView.selectedTextRange ?? textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument)!
                
                // Yep. This is just a delight.
                let precedingOffset = max(-2, textView.offset(from: selectedRange.start, to: textView.beginningOfDocument))
                if precedingOffset < 0 {
                    let precedingStart = textView.position(from: selectedRange.start, offset: precedingOffset)
                    let precedingRange = textView.textRange(from: precedingStart!, to: selectedRange.start)
                    let preceding = textView.text(in: precedingRange!)
                    if preceding != "\n\n" {
                        if preceding!.hasSuffix("\n") {
                            replacement = "\n" + replacement
                        } else {
                            replacement = "\n\n" + replacement
                        }
                    }
                }
                
                textView.replace(selectedRange, withText: replacement)
            }
            
            completion(error)
        }
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
            if let draft = DraftStore.sharedStore().loadDraft(path) as! ReplyDraft? {
                return self.init(draft: draft, didRestoreWithRestorationIdentifier: identifierComponents.last )
            }
        }
        
        NSLog("[%@ %@] failing intentionally as no saved draft was found", self.description(), #function)
        return nil
    }
    
    func decodeRestorableState(with coder: NSCoder) {
        // Our encoded CompositionViewController is not available any earlier (i.e. in objectWithRestorationIdentifierPath(_:coder:)).
        compositionViewController = coder.decodeObject(forKey: Keys.compositionViewController) as! CompositionViewController
    }

    fileprivate struct Keys {
        static let draftPath = "draftPath"
        static let compositionViewController = "compositionViewController"
    }
}

@objc protocol ReplyDraft: StorableDraft, SubmittableDraft, ReplyUI {
    var thread: AwfulThread { get }
    var text: NSAttributedString? { get set }
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
    
    init(thread: AwfulThread, text: NSAttributedString? = nil) {
        self.thread = thread
        self.text = text
        super.init()
    }
    
    convenience init?(coder: NSCoder) {
        let threadKey = coder.decodeObject(forKey: Keys.threadKey) as! ThreadKey
        let thread = AwfulThread.objectForKey(objectKey: threadKey, inManagedObjectContext: AppDelegate.instance.managedObjectContext) as! AwfulThread
        let text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        self.init(thread: thread, text: text)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(thread.objectKey, forKey: Keys.threadKey)
        coder.encode(text, forKey: Keys.text)
    }
    
    fileprivate struct Keys {
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
    
    convenience init?(coder: NSCoder) {
        let postKey = coder.decodeObject(forKey: Keys.postKey) as! PostKey
        let post = Post.objectForKey(objectKey: postKey, inManagedObjectContext: AppDelegate.instance.managedObjectContext) as! Post
        let text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        self.init(post: post, text: text)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(post.objectKey, forKey: Keys.postKey)
        coder.encode(text, forKey: Keys.text)
    }
    
    fileprivate struct Keys {
        static let postKey = "postKey"
        static let text = "text"
    }
    
    var thread: AwfulThread {
        // TODO can we assume an edited post always has a thread?
        return post.thread!
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
                AwfulForumsClient.shared().reply(to: self.thread, withBBcode: plainText) { (error: Error?, post: Post?) in
                    completion(error)
                }
            }
        }
    }
}

extension EditReplyDraft: SubmittableDraft {
    func submit(_ completion: @escaping (Error?) -> Void) -> Progress {
        return uploadImages(attachedTo: text!) { [unowned self] plainText, error in
            if let error = error {
                completion(error)
            } else {
                _ = AwfulForumsClient.shared().edit(self.post, setBBcode: plainText, andThen: completion)
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
