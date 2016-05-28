//  LoginViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

class LoginViewController: AwfulViewController {
    var completionBlock: ((LoginViewController) -> Void)?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var nextBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var onePasswordButton: UIButton!
    @IBOutlet var onePasswordUnavailableConstraints: [NSLayoutConstraint]!
    
    private enum State {
        case AwaitingUsername
        case AwaitingPassword
        case CanAttemptLogin
        case AttemptingLogin
        case FailedLogin
    }
    
    private var state: State = .AwaitingUsername {
        didSet {
            switch(state) {
            case .AwaitingUsername, .AwaitingPassword:
                usernameTextField.enabled = true
                passwordTextField.enabled = true
                nextBarButtonItem.enabled = false
            case .CanAttemptLogin:
                usernameTextField.enabled = true
                passwordTextField.enabled = true
                nextBarButtonItem.enabled = true
                forgotPasswordButton.hidden = false
            case .AttemptingLogin:
                usernameTextField.enabled = false
                passwordTextField.enabled = false
                nextBarButtonItem.enabled = false
                forgotPasswordButton.hidden = true
                activityIndicator.startAnimating()
            case .FailedLogin:
                activityIndicator.stopAnimating()
                let alert = UIAlertController(title: "Problem Logging In", message: "Double-check your username and password, then try again.") { action in
                    self.state = .CanAttemptLogin
                    self.passwordTextField.becomeFirstResponder()
                }
                presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    class func newFromStoryboard() -> LoginViewController {
        return UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! LoginViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Can't set this in the storyboard for some reason.
        nextBarButtonItem.enabled = false
        
        if !OnePasswordExtension.sharedExtension().isAppExtensionAvailable() {
            onePasswordButton.removeFromSuperview()
            view.addConstraints(onePasswordUnavailableConstraints)
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(LoginViewController.keyboardWillChangeFrame(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        usernameTextField.becomeFirstResponder()
    }
    
    @IBAction func didTapNext() {
        attemptToLogIn()
    }
    
    @IBAction func didChangeUsername(sender: UITextField) {
        if sender.text!.isEmpty {
            state = .AwaitingUsername
        } else if passwordTextField.text!.isEmpty {
            state = .AwaitingPassword
        } else {
            state = .CanAttemptLogin
        }
    }
    
    @IBAction func didChangePassword(sender: UITextField) {
        if sender.text!.isEmpty {
            state = .AwaitingPassword
        } else if usernameTextField.text!.isEmpty {
            state = .AwaitingUsername
        } else {
            state = .CanAttemptLogin
        }
    }
    
    @IBAction func didTapOnePassword(sender: AnyObject) {
        view.endEditing(true)
        
        OnePasswordExtension.sharedExtension().findLoginForURLString("forums.somethingawful.com", forViewController: self, sender: sender) { [weak self] (loginInfo, error) -> Void in
            if loginInfo == nil {
                if error.code != AppExtensionErrorCodeCancelledByUser {
                    NSLog("[\(Mirror(reflecting: self)) \(#function)] 1Password extension failed: \(error)")
                }
                return
            }
            self?.usernameTextField.text = loginInfo[AppExtensionUsernameKey] as! NSString as String
            self?.passwordTextField.text = loginInfo[AppExtensionPasswordKey] as! NSString as String
            self?.state = .CanAttemptLogin
        }
    }
    
    private func attemptToLogIn() {
        assert(state == .CanAttemptLogin, "unexpected state")
        state = .AttemptingLogin
        AwfulForumsClient.sharedClient().logInWithUsername(usernameTextField.text, password: passwordTextField.text) { [unowned self] (error, user) -> Void in
            if let user = user {
                let settings = AwfulSettings.sharedSettings()
                settings.username = user.username
                settings.userID = user.userID
                settings.canSendPrivateMessages = user.canReceivePrivateMessages
                if let completionBlock = self.completionBlock {
                    completionBlock(self)
                }
            } else {
                self.state = .FailedLogin
            }
        }
    }
    
    @IBAction func didTapForgetPassword() {
        let URL = NSURL(string: "https://forums.somethingawful.com/account.php?action=lostpw")!
        UIApplication.sharedApplication().openURL(URL)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        let targetRect = scrollView.convertRect(textField.bounds, fromView: textField)
        scrollView.scrollRectToVisible(CGRectInset(targetRect, 0, -8), animated: true)
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        switch (state) {
        case .AwaitingUsername:
            usernameTextField.becomeFirstResponder()
        case .AwaitingPassword:
            passwordTextField.becomeFirstResponder()
        case .CanAttemptLogin:
            attemptToLogIn()
        default:
            fatalError("unexpected state")
        }
        return true
    }
}

extension LoginViewController {
    @objc private func keyboardWillChangeFrame(notification: NSNotification) {
        let userInfo = notification.userInfo as! [NSObject:NSObject]

        // For whatever insane reason, iOS9 gives you keyboard events for things that happen in extensions.
        // Check to make sure the keyboard is actually "ours", because `self.view.window` is apparently nil if 1Password is using the keyboard.
        let isLocal = userInfo[UIKeyboardIsLocalUserInfoKey] as? Bool
        if (isLocal != nil && isLocal == false) {
            return;
        }
        
        let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber
        let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber
        let options = UIViewAnimationOptions(rawValue: UInt(curve.unsignedIntegerValue) << 16)
        UIView.animateWithDuration(duration.doubleValue, delay: 0, options: options, animations: {
            let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
            let windowKeyboardFrame = self.view.window!.convertRect(keyboardFrame, fromWindow: nil)
            let localKeyboardFrame = self.view.convertRect(windowKeyboardFrame, fromView: nil)
            let insetBottom = CGRectIntersection(localKeyboardFrame, self.view.bounds).height
            
            var contentInsets = self.scrollView.contentInset
            contentInsets.bottom = insetBottom
            self.scrollView.contentInset = contentInsets
            
            var scrollIndicatorInsets = self.scrollView.scrollIndicatorInsets
            scrollIndicatorInsets.bottom = insetBottom
            self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
        }, completion: nil)
    }
}
