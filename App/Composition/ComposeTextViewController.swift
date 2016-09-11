//  ComposeTextViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MRProgress

class ComposeTextViewController: ViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
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
    fileprivate(set) lazy var submitButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Submit", style: .plain, target: self, action: #selector(didTapSubmit))
    }()
    
    /// The button that cancels the composition when tapped. Set its title as appropriate.
    fileprivate(set) lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didTapCancel))
    }()
    
    /// Tells a reasonable responder to become first responder.
    func focusInitialFirstResponder() {
        let responder = customView?.initialFirstResponder ?? textView
        responder.becomeFirstResponder()
    }
    
    /// Refreshes the submit button's enabled status.
    func updateSubmitButtonItem() {
        submitButtonItem.isEnabled = canSubmitComposition
    }
    
    /// Returns YES when the submission is valid and ready, otherwise NO. The default is to return YES when the textView is nonempty.
    var canSubmitComposition: Bool {
        return !textView.text.isEmpty
    }
    
    /**
        Called just before submission, offering a chance to confirm whether the submission should continue. The default implementation immediately allows submission.
     
        - parameter handler: A block to call after determining whether submission should continue, which takes as a parameter YES if submission should continue or NO otherwise.
     */
    func shouldSubmit(_ handler: @escaping (Bool) -> Void) {
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
    func submit(_ composition: String, completion: @escaping (_ success: Bool) -> Void) {
        fatalError("\(type(of: self)) needs to implement \(#function)")
    }
    
    /// Called when the cancel button is tapped and no submission is in progress. The default implementation simply informs the delegate; overridden implementations can do so directly or call super as desired.
    func cancel() {
        if let delegate = delegate {
            delegate.composeTextViewController(self, didFinishWithSuccessfulSubmission: false, shouldKeepDraft: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    /// A view that perches atop the textView, housing additional fields like a "Subject" field or a thread tag picker. Should be an instance of UIView, even though I'm not bothering to use the type system to enforce that right now because it's slightly too annoying.
    var customView: ComposeCustomView? {
        willSet {
            guard let old = customView as? UIView else { return }
            
            old.removeFromSuperview()
            
            customViewWidthConstraint?.isActive = false
            customViewWidthConstraint = nil
        }
        didSet {
            if let old = oldValue as? UIView , customView == nil {
                textView.textContainerInset.top -= old.bounds.height
            }
            
            guard let customView = customView as? UIView else { return }
            customView.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(customView)
            
            textView.textContainerInset.top += customView.bounds.height
            
            textView.leadingAnchor.constraint(equalTo: customView.leadingAnchor).isActive = true
            textView.topAnchor.constraint(equalTo: customView.topAnchor).isActive = true
            customView.heightAnchor.constraint(equalToConstant: customView.bounds.height).isActive = true
            customViewWidthConstraint = customView.widthAnchor.constraint(equalToConstant: view.bounds.width)
            
            // If we're not in the view controller hierarchy, we might not yet have a width, in which case we'll add the constraint later.
            if let constraint = customViewWidthConstraint , constraint.constant > 0 {
                constraint.isActive = true
            }
        }
    }
    
    fileprivate var customViewWidthConstraint: NSLayoutConstraint?
    
    weak var delegate: ComposeTextViewControllerDelegate?
    
    fileprivate var menuTree: CompositionMenuTree!
    
    fileprivate func beginObservingTextChangeNotification() {
        guard textDidChangeObserver == nil else { return }
        textDidChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextViewTextDidChange, object: textView, queue: OperationQueue.main, using: { [weak self] (note: Notification) in
            self?.updateSubmitButtonItem()
        })
    }
    private func endObservingTextChangeNotification() {
        guard let token = textDidChangeObserver else { return }
        NotificationCenter.default.removeObserver(token)
        textDidChangeObserver = nil
    }
    private var textDidChangeObserver: NSObjectProtocol?
    
    fileprivate func beginObservingKeyboardNotifications() {
        guard keyboardWillShowObserver == nil else { return }
        
        keyboardWillShowObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillShow, object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in
            self?.keyboardWillThingy(notification)
        })
        
        keyboardWillHideObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in
            self?.keyboardWillThingy(notification)
        })
    }
    private func endObservingKeyboardNotifications() {
        if let token = keyboardWillShowObserver {
            NotificationCenter.default.removeObserver(token)
            keyboardWillShowObserver = nil
        }
        
        if let token = keyboardWillHideObserver {
            NotificationCenter.default.removeObserver(token)
            keyboardWillHideObserver = nil
        }
    }
    private var keyboardWillShowObserver: NSObjectProtocol?
    fileprivate var keyboardWillHideObserver: NSObjectProtocol?
    
    fileprivate func keyboardWillThingy(_ notification: Notification) {
        guard let
            duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let curve = notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? UInt,
            let keyboardEndScreenFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let window = view.window
            else { return }
        let keyboardEndTextViewFrame = textView.convert(keyboardEndScreenFrame, to: window.screen.coordinateSpace)
        let overlap = keyboardEndTextViewFrame.intersection(textView.bounds)
        
        let options = UIViewAnimationOptions(rawValue: curve << 16)
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: { 
            self.textView.contentInset.bottom = overlap.height
            self.textView.scrollIndicatorInsets.bottom = overlap.height
            }) { (finished) in
                guard let
                    endPosition = self.textView.selectedTextRange?.end
                    , notification.name == NSNotification.Name.UIKeyboardWillShow
                    else { return }
                let caretRect = self.textView.caretRect(for: endPosition)
                self.textView.scrollRectToVisible(caretRect, animated: true)
        }
    }
    
    fileprivate var imageUploadProgress: Progress?
    
    fileprivate func submit() {
        let overlay = MRProgressOverlayView.showOverlayAdded(to: viewToOverlay, title: submissionInProgressTitle, mode: .indeterminate, animated: true)
        overlay?.tintColor = theme["tintColor"]
        
        imageUploadProgress = uploadImages(attachedTo: textView.attributedText, completion: { [weak self] (plainText, error) in
            if let error = error {
                overlay?.dismiss(false)
                
                self?.enableEverything()
                
                if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError {
                    self?.focusInitialFirstResponder()
                } else {
                    // In case we're covered up by subsequent view controllers (console message about "detached view controllers"), aim for our navigation controller.
                    let presenter = self?.navigationController ?? self
                    presenter?.present(UIAlertController.alertWithTitle("Image Upload Failed", error: error), animated: true, completion: nil)
                }
                
                return
            }
            
            guard let plainText = plainText else { fatalError("no error should mean yes plain text") }
            self?.submit(plainText, completion: { [weak self] (success) in
                if success {
                    if let delegate = self?.delegate {
                        delegate.composeTextViewController(self!, didFinishWithSuccessfulSubmission: true, shouldKeepDraft: false)
                    } else {
                        self?.dismiss(animated: true, completion: nil)
                    }
                } else {
                    self?.enableEverything()
                    
                    self?.focusInitialFirstResponder()
                    
                    return
                }
            })
        })
    }
    
    fileprivate var viewToOverlay: UIView {
        if let top = navigationController?.topViewController {
            return top.view
        } else {
            return view
        }
    }
    
    fileprivate func enableEverything() {
        updateSubmitButtonItem()
        
        textView.isEditable = true
        customView?.enabled = true
    }
    
    fileprivate func disableEverythingButTheCancelButton() {
        view.endEditing(true)
        
        submitButtonItem.isEnabled = false
        textView.isEditable = false
        customView?.enabled = false
    }
    
    @objc fileprivate func didTapSubmit() {
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
    
    @objc fileprivate func didTapCancel() {
        if let progress = imageUploadProgress {
            progress.cancel()
            imageUploadProgress = nil
            
            MRProgressOverlayView.dismissAllOverlays(for: viewToOverlay, animated: true, completion: { 
                self.enableEverything()
            })
        } else {
            cancel()
        }
    }
    
    override func loadView() {
        let textView = ComposeTextView()
        textView.restorationIdentifier = "ComposeTextView"
        textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
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
        
        if let constraint = customViewWidthConstraint , view.bounds.width > 0 {
            constraint.constant = view.bounds.width
            
            // If our view wasn't already in the hierarchy when the custom view was added, we didn't know how wide to make the custom view. Now we do.
            constraint.isActive = true
            
            view.layoutSubviews()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        focusInitialFirstResponder()
        
        updateSubmitButtonItem()
        
        beginObservingKeyboardNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        beginObservingTextChangeNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.endEditing(true)
    }
    
    // MARK: State restoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(textView.attributedText, forKey: Keys.AttributedText.rawValue)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        textView.attributedText = coder.decodeObject(forKey: Keys.AttributedText.rawValue) as? NSAttributedString
        
        // -viewDidLoad gets called before -decodeRestorableStateWithCoder: and so the text color gets loaded from the saved attributed string. Reapply the theme after restoring state.
        themeDidChange()
        
        updateSubmitButtonItem()
    }
}

fileprivate enum Keys: String {
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
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool)
}
