//  ComposeTextViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MRProgress

class ComposeTextViewController: AwfulViewController {
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
        navigationItem.leftBarButtonItem = cancelButtonItem
        navigationItem.rightBarButtonItem = submitButtonItem
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        endObservingTextChangeNotification()
        endObservingKeyboardNotifications()
    }
    
    /// The composition text view. Set its text or attributedText property as appropriate.
    var textView: UITextView {
        return view as! UITextView
    }
    
    /// The button that submits the composition when tapped. Set its title property.
    private(set) lazy var submitButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Submit", style: .Plain, target: self, action: #selector(didTapSubmit))
    }()
    
    /// The button that cancels the composition when tapped. Set its title as appropriate.
    private(set) lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Cancel", style: .Plain, target: self, action: #selector(didTapCancel))
    }()
    
    /// Tells a reasonable responder to become first responder.
    func focusInitialFirstResponder() {
        let responder = customView?.initialFirstResponder ?? textView
        responder.becomeFirstResponder()
    }
    
    /// Refreshes the submit button's enabled status.
    func updateSubmitButtonItem() {
        submitButtonItem.enabled = canSubmitComposition
    }
    
    /// Returns YES when the submission is valid and ready, otherwise NO. The default is to return YES when the textView is nonempty.
    var canSubmitComposition: Bool {
        return !textView.text.isEmpty
    }
    
    /**
        Called just before submission, offering a chance to confirm whether the submission should continue. The default implementation immediately allows submission.
     
        - parameter handler: A block to call after determining whether submission should continue, which takes as a parameter YES if submission should continue or NO otherwise.
     */
    func shouldSubmit(handler: (Bool) -> Void) {
        handler(true)
    }
    
    /// Returns a description of the process of submission, such as "Posting…".
    var submissionInProgressTitle: String {
        return "Posting…"
    }
    
    /**
        Do the actual work of submitting the composition. The default implementation crashes.
     
        - parameter composition: The composition with upload images having been replaced by appropriate textual equivalents.
        - parameter completion: A block to call once submission is complete; the block takes a single parameter, either YES on success or NO if submission failed.
     */
    func submit(composition: String, completion: (success: Bool) -> Void) {
        fatalError("\(self.dynamicType) needs to implement \(#function)")
    }
    
    /// Called when the cancel button is tapped and no submission is in progress. The default implementation simply informs the delegate; overridden implementations can do so directly or call super as desired.
    func cancel() {
        if let delegate = delegate {
            delegate.composeTextViewController(self, didFinishWithSuccessfulSubmission: false, shouldKeepDraft: true)
        } else {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    /// A view that perches atop the textView, housing additional fields like a "Subject" field or a thread tag picker. Should be an instance of UIView, even though I'm not bothering to use the type system to enforce that right now because it's slightly too annoying.
    var customView: ComposeCustomView? {
        willSet {
            guard let old = customView as? UIView else { return }
            
            old.removeFromSuperview()
            
            customViewWidthConstraint?.active = false
            customViewWidthConstraint = nil
        }
        didSet {
            if let old = oldValue as? UIView where customView == nil {
                textView.textContainerInset.top -= old.bounds.height
            }
            
            guard let customView = customView as? UIView else { return }
            customView.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(customView)
            
            textView.textContainerInset.top += customView.bounds.height
            
            textView.leadingAnchor.constraintEqualToAnchor(customView.leadingAnchor).active = true
            textView.topAnchor.constraintEqualToAnchor(customView.topAnchor).active = true
            customView.heightAnchor.constraintEqualToConstant(customView.bounds.height).active = true
            customViewWidthConstraint = customView.widthAnchor.constraintEqualToConstant(view.bounds.width)
            
            // If we're not in the view controller hierarchy, we might not yet have a width, in which case we'll add the constraint later.
            if let constraint = customViewWidthConstraint where constraint.constant > 0 {
                constraint.active = true
            }
        }
    }
    
    private var customViewWidthConstraint: NSLayoutConstraint?
    
    weak var delegate: ComposeTextViewControllerDelegate?
    
    private var menuTree: CompositionMenuTree!
    
    private func beginObservingTextChangeNotification() {
        guard textDidChangeObserver == nil else { return }
        textDidChangeObserver = NSNotificationCenter.defaultCenter().addObserverForName(UITextViewTextDidChangeNotification, object: textView, queue: NSOperationQueue.mainQueue(), usingBlock: { [weak self] (note: NSNotification) in
            self?.updateSubmitButtonItem()
        })
    }
    private func endObservingTextChangeNotification() {
        guard let token = textDidChangeObserver else { return }
        NSNotificationCenter.defaultCenter().removeObserver(token)
        textDidChangeObserver = nil
    }
    private var textDidChangeObserver: NSObjectProtocol?
    
    private func beginObservingKeyboardNotifications() {
        guard keyboardWillShowObserver == nil else { return }
        
        keyboardWillShowObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillShowNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { [weak self] (notification) in
            self?.keyboardWillThingy(notification)
        })
        
        keyboardWillHideObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillHideNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { [weak self] (notification) in
            self?.keyboardWillThingy(notification)
        })
    }
    private func endObservingKeyboardNotifications() {
        if let token = keyboardWillShowObserver {
            NSNotificationCenter.defaultCenter().removeObserver(token)
            keyboardWillShowObserver = nil
        }
        
        if let token = keyboardWillHideObserver {
            NSNotificationCenter.defaultCenter().removeObserver(token)
            keyboardWillHideObserver = nil
        }
    }
    private var keyboardWillShowObserver: NSObjectProtocol?
    private var keyboardWillHideObserver: NSObjectProtocol?
    
    private func keyboardWillThingy(notification: NSNotification) {
        guard let
            duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval,
            curve = notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? UInt,
            keyboardEndScreenFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(),
            window = view.window
            else { return }
        let keyboardEndTextViewFrame = textView.convertRect(keyboardEndScreenFrame, fromCoordinateSpace: window.screen.coordinateSpace)
        let overlap = keyboardEndTextViewFrame.intersect(textView.bounds)
        
        let options = UIViewAnimationOptions(rawValue: curve << 16)
        
        UIView.animateWithDuration(duration, delay: 0, options: options, animations: { 
            self.textView.contentInset.bottom = overlap.height
            self.textView.scrollIndicatorInsets.bottom = overlap.height
            }) { (finished) in
                guard let
                    endPosition = self.textView.selectedTextRange?.end
                    where notification.name == UIKeyboardWillShowNotification
                    else { return }
                let caretRect = self.textView.caretRectForPosition(endPosition)
                self.textView.scrollRectToVisible(caretRect, animated: true)
        }
    }
    
    private var imageUploadProgress: NSProgress?
    
    private func submit() {
        let overlay = MRProgressOverlayView.showOverlayAddedTo(viewToOverlay, title: submissionInProgressTitle, mode: .Indeterminate, animated: true)
        overlay.tintColor = theme["tintColor"]
        
        imageUploadProgress = UploadImageAttachments(textView.attributedText, { [weak self] (plainText, error) in
            if let error = error {
                overlay.dismiss(false)
                
                self?.enableEverything()
                
                if error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError {
                    self?.focusInitialFirstResponder()
                } else {
                    // In case we're covered up by subsequent view controllers (console message about "detached view controllers"), aim for our navigation controller.
                    let presenter = self?.navigationController ?? self
                    presenter?.presentViewController(UIAlertController.alertWithTitle("Image Upload Failed", error: error), animated: true, completion: nil)
                }
                
                return
            }
            
            self?.submit(plainText, completion: { [weak self] (success) in
                if success {
                    if let delegate = self?.delegate {
                        delegate.composeTextViewController(self!, didFinishWithSuccessfulSubmission: true, shouldKeepDraft: false)
                    } else {
                        self?.dismissViewControllerAnimated(true, completion: nil)
                    }
                } else {
                    self?.enableEverything()
                    
                    self?.focusInitialFirstResponder()
                    
                    return
                }
            })
        })
    }
    
    private var viewToOverlay: UIView {
        if let top = navigationController?.topViewController {
            return top.view
        } else {
            return view
        }
    }
    
    private func enableEverything() {
        updateSubmitButtonItem()
        
        textView.editable = true
        customView?.enabled = true
    }
    
    private func disableEverythingButTheCancelButton() {
        view.endEditing(true)
        
        submitButtonItem.enabled = false
        textView.editable = false
        customView?.enabled = false
    }
    
    @objc private func didTapSubmit() {
        disableEverythingButTheCancelButton()
        shouldSubmit({ [weak self] (ok: Bool) in
            if ok {
                self?.submit()
            } else {
                self?.imageUploadProgress?.cancel()
                self?.imageUploadProgress = nil
                
                self?.enableEverything()
                
                self?.focusInitialFirstResponder()
            }
        })
    }
    
    @objc private func didTapCancel() {
        if let progress = imageUploadProgress {
            progress.cancel()
            imageUploadProgress = nil
            
            MRProgressOverlayView.dismissAllOverlaysForView(viewToOverlay, animated: true, completion: { 
                self.enableEverything()
            })
        } else {
            cancel()
        }
    }
    
    override func loadView() {
        let textView = ComposeTextView()
        textView.restorationIdentifier = "ComposeTextView"
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        textView.delegate = self
        view = textView
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        textView.textColor = theme["listTextColor"]
        textView.keyboardAppearance = theme.keyboardAppearance
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        menuTree = CompositionMenuTree(textView: textView)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let constraint = customViewWidthConstraint where view.bounds.width > 0 {
            constraint.constant = view.bounds.width
            
            // If our view wasn't already in the hierarchy when the custom view was added, we didn't know how wide to make the custom view. Now we do.
            constraint.active = true
            
            view.layoutSubviews()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        focusInitialFirstResponder()
        
        updateSubmitButtonItem()
        
        beginObservingKeyboardNotifications()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        beginObservingTextChangeNotification()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.endEditing(true)
    }
    
    // MARK: State restoration
    
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(textView.attributedText, forKey: Keys.AttributedText.rawValue)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        super.decodeRestorableStateWithCoder(coder)
        
        textView.attributedText = coder.decodeObjectForKey(Keys.AttributedText.rawValue) as? NSAttributedString
        
        // -viewDidLoad gets called before -decodeRestorableStateWithCoder: and so the text color gets loaded from the saved attributed string. Reapply the theme after restoring state.
        themeDidChange()
        
        updateSubmitButtonItem()
    }
}

private enum Keys: String {
    case AttributedText
}

// For benefit of subclasses.
extension ComposeTextViewController: UITextViewDelegate {}

protocol ComposeCustomView {
    var enabled: Bool { get set }
    
    /// Returns a responder that should be the initial first responder when the AwfulComposeTextViewController first appears, instead of its textView. The default is nil, meaning the textView becomes first responder as usual.
    var initialFirstResponder: UIResponder? { get }
}

@objc protocol ComposeTextViewControllerDelegate: class {
    /**
        Sent to the delegate when composition is either submitted or cancelled.
     
        - parameter success: true if the submission was successful, otherwise false.
        - parameter keepDraft: true if the view controller should be kept around, otherwise false.
     */
    func composeTextViewController(composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool)
}
