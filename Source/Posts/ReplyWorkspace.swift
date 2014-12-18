//  ReplyWorkspace.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
    
    convenience init(thread: Thread) {
        let draft = ReplyDraft(thread: thread)
        self.init(draft: draft, didRestoreWithRestorationIdentifier: nil)
    }
    
    /// A nil restorationIdentifier implies that we were not created by UIKit state restoration.
    private init(draft: ReplyDraft, didRestoreWithRestorationIdentifier restorationIdentifier: String?) {
        self.draft = draft
        self.restorationIdentifier = restorationIdentifier ?? NSUUID().UUIDString
        super.init()
        
        UIApplication.registerObjectForStateRestoration(self, restorationIdentifier: self.restorationIdentifier)
    }
    
    /*
    Dealing with compositionViewController is annoyingly complicated. Ideally it'd be a constant ivar, so we could either restore state by passing it in via init() or make a new one if we're not restoring state.
    Unfortunately, any compositionViewController that we preserve in encodeRestorableStateWithCoder() is not yet available in objectWithRestorationIdentifierPath(_:coder:); it only becomes available in decodeRestorableStateWithCoder().
    This didSet encompasses the junk we want to set up on the compositionViewController no matter how it's created and really belongs in init(), except we're stuck.
    */
    private var compositionViewController: CompositionViewController! {
        didSet {
            assert(oldValue == nil, "please set compositionViewController only once")
            
            compositionViewController.textView.attributedText = draft.text
            KVOController.observe(draft.thread, keyPath: "title", options: .Initial) { [unowned self] thread, change in
                self.compositionViewController.title = thread.title
            }
            
            let navigationItem = compositionViewController.navigationItem
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapCancel:")
            navigationItem.rightBarButtonItem = rightButtonItem
            KVOController.observe(AwfulSettings.sharedSettings(), keyPath: AwfulSettingsKeys.confirmNewPosts, options: .Initial) { [unowned self] _, _ in
                self.updateRightButtonItem()
            }
        }
    }
    
    private lazy var rightButtonItem: UIBarButtonItem = { [unowned self] in
        return UIBarButtonItem(title: "Post", style: .Done, target: self, action: "didTapPost:")
        }()
    
    private func updateRightButtonItem() {
        if AwfulSettings.sharedSettings().confirmNewPosts {
            rightButtonItem.title = "Preview"
            rightButtonItem.action = "didTapPreview:"
        } else {
            rightButtonItem.title = "Post"
            rightButtonItem.action = "didTapPost:"
        }
    }
    
    @objc private func didTapCancel(sender: UIBarButtonItem) {
        completion?(saveDraft: true, didSucceed: false)
    }
    
    @objc private func didTapPreview(sender: UIBarButtonItem) {
        let preview = PostPreviewViewController(thread: draft.thread, BBcode: compositionViewController.textView.attributedText)
        preview.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Post", style: .Done, target: self, action: "didTapPost:")
        (viewController as UINavigationController).pushViewController(preview, animated: true)
    }
    
    @objc private func didTapPost(sender: UIBarButtonItem) {
        let progressView = MRProgressOverlayView.showOverlayAddedTo(viewController.view.window, animated: true)
        progressView.tintColor = viewController.view.tintColor
        
        // TODO upload images, cancelable by tapping on overlay
        
        progressView.titleLabelText = "Posting…"
        AwfulForumsClient.sharedClient().replyToThread(draft.thread, withBBcode: compositionViewController.textView.text) { [unowned self] error, post in
            progressView.dismiss(true)
            
            if let error = error {
                if !(error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError) {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    self.viewController.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                DraftStore.sharedStore().deleteDraft(self.draft)
                
                self.completion?(saveDraft: false, didSucceed: true)
            }
        }
    }
    
    /// Present this view controller to let someone compose a reply.
    var viewController: UIViewController {
        if compositionViewController == nil {
            compositionViewController = CompositionViewController()
            compositionViewController.restorationIdentifier = "\(self.restorationIdentifier) Reply composition"
        }
        
        return compositionViewController.enclosingNavigationController
    }
}

extension ReplyWorkspace: UIObjectRestoration, UIStateRestoring {
    var objectRestorationClass: AnyObject.Type {
        return ReplyWorkspace.self
    }
    
    func encodeRestorableStateWithCoder(coder: NSCoder) {
        draft.text = compositionViewController.textView.attributedText
        DraftStore.sharedStore().saveDraft(draft)
        coder.encodeObject(draft.storePath, forKey: Keys.draftPath)
        coder.encodeObject(compositionViewController, forKey: Keys.compositionViewController)
    }
    
    class func objectWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIStateRestoring? {
        if let path = coder.decodeObjectForKey(Keys.draftPath) as String? {
            if let draft = DraftStore.sharedStore().loadDraft(path) as ReplyDraft? {
                return self(draft: draft, didRestoreWithRestorationIdentifier: identifierComponents.last as String?)
            }
        }
        
        NSLog("[%@ %@] failing intentionally as no saved draft was found", self.description(), __FUNCTION__)
        return nil
    }
    
    func decodeRestorableStateWithCoder(coder: NSCoder!) {
        // Our encoded CompositionViewController is not available any earlier (i.e. in objectWithRestorationIdentifierPath(_:coder:)).
        compositionViewController = coder.decodeObjectForKey(Keys.compositionViewController) as CompositionViewController
    }

    private struct Keys {
        static let draftPath = "draftPath"
        static let compositionViewController = "compositionViewController"
    }
}

final class ReplyDraft: NSObject, NSCoding, StorableDraft {
    let thread: Thread
    var text: NSAttributedString?
    
    init(thread: Thread, text: NSAttributedString? = nil) {
        self.thread = thread
        self.text = text
        super.init()
    }
    
    convenience init(coder: NSCoder) {
        let threadKey = coder.decodeObjectForKey(Keys.threadKey) as ThreadKey
        let thread = Thread.objectForKey(threadKey, inManagedObjectContext: AwfulAppDelegate.instance().managedObjectContext) as Thread
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
