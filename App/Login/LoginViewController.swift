//  LoginViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

class LoginViewController: ViewController {
    var completionBlock: ((LoginViewController) -> Void)?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var nextBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var onePasswordButton: UIButton!
    @IBOutlet var onePasswordUnavailableConstraints: [NSLayoutConstraint]!
    
    fileprivate enum State {
        case awaitingUsername
        case awaitingPassword
        case canAttemptLogin
        case attemptingLogin
        case failedLogin
    }
    
    fileprivate var state: State = .awaitingUsername {
        didSet {
            switch(state) {
            case .awaitingUsername, .awaitingPassword:
                usernameTextField.isEnabled = true
                passwordTextField.isEnabled = true
                nextBarButtonItem.isEnabled = false
            case .canAttemptLogin:
                usernameTextField.isEnabled = true
                passwordTextField.isEnabled = true
                nextBarButtonItem.isEnabled = true
                forgotPasswordButton.isHidden = false
            case .attemptingLogin:
                usernameTextField.isEnabled = false
                passwordTextField.isEnabled = false
                nextBarButtonItem.isEnabled = false
                forgotPasswordButton.isHidden = true
                activityIndicator.startAnimating()
            case .failedLogin:
                activityIndicator.stopAnimating()
                let alert = UIAlertController(title: "Problem Logging In", message: "Double-check your username and password, then try again.") { action in
                    self.state = .canAttemptLogin
                    self.passwordTextField.becomeFirstResponder()
                }
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func newFromStoryboard() -> LoginViewController {
        return UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! LoginViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Can't set this in the storyboard for some reason.
        nextBarButtonItem.isEnabled = false
        
        if !OnePasswordExtension.shared().isAppExtensionAvailable() {
            onePasswordButton.removeFromSuperview()
            view.addConstraints(onePasswordUnavailableConstraints)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        usernameTextField.becomeFirstResponder()
    }
    
    @IBAction func didTapNext() {
        attemptToLogIn()
    }
    
    @IBAction func didChangeUsername(_ sender: UITextField) {
        if sender.text!.isEmpty {
            state = .awaitingUsername
        } else if passwordTextField.text!.isEmpty {
            state = .awaitingPassword
        } else {
            state = .canAttemptLogin
        }
    }
    
    @IBAction func didChangePassword(_ sender: UITextField) {
        if sender.text!.isEmpty {
            state = .awaitingPassword
        } else if usernameTextField.text!.isEmpty {
            state = .awaitingUsername
        } else {
            state = .canAttemptLogin
        }
    }
    
    @IBAction func didTapOnePassword(_ sender: AnyObject) {
        view.endEditing(true)
        
        OnePasswordExtension.shared().findLogin(forURLString: "forums.somethingawful.com", for: self, sender: sender) { [weak self] (loginInfo, error) -> Void in
            if loginInfo == nil {
                if (error as NSError?)?.code != AppExtensionErrorCodeCancelledByUser {
                    NSLog("[\(String(describing: self)) \(#function)] 1Password extension failed: \(String(describing: error))")
                }
                return
            }
            self?.usernameTextField.text = loginInfo?[AppExtensionUsernameKey] as? String
            self?.passwordTextField.text = loginInfo?[AppExtensionPasswordKey] as? String
            self?.state = .canAttemptLogin
        }
    }
    
    fileprivate func attemptToLogIn() {
        assert(state == .canAttemptLogin, "unexpected state")
        state = .attemptingLogin
        ForumsClient.shared.logIn(username: usernameTextField.text ?? "",
                                  password: passwordTextField.text ?? "")
            .then { (user) -> Void in
                let settings = AwfulSettings.shared()!
                settings.username = user.username
                settings.userID = user.userID
                settings.canSendPrivateMessages = user.canReceivePrivateMessages
                if let completionBlock = self.completionBlock {
                    completionBlock(self)
                }
            }
            .catch { (error) in
                self.state = .failedLogin
        }
    }
    
    @IBAction func didTapForgetPassword() {
        let URL = Foundation.URL(string: "https://forums.somethingawful.com/account.php?action=lostpw")!
        UIApplication.shared.openURL(URL)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        let targetRect = scrollView.convert(textField.bounds, from: textField)
        scrollView.scrollRectToVisible(targetRect.insetBy(dx: 0, dy: -8), animated: true)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch (state) {
        case .awaitingUsername:
            usernameTextField.becomeFirstResponder()
        case .awaitingPassword:
            passwordTextField.becomeFirstResponder()
        case .canAttemptLogin:
            attemptToLogIn()
        default:
            fatalError("unexpected state")
        }
        return true
    }
}

extension LoginViewController {
    @objc fileprivate func keyboardWillChangeFrame(_ notification: Notification) {
        // For whatever insane reason, iOS9 gives you keyboard events for things that happen in extensions.
        // Check to make sure the keyboard is actually "ours", because `self.view.window` is apparently nil if 1Password is using the keyboard.
        let isLocal = notification.userInfo?[UIKeyboardIsLocalUserInfoKey] as? Bool
        if (isLocal != nil && isLocal == false) {
            return;
        }
        
        let duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber
        let curve = notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber
        let options = UIViewAnimationOptions(rawValue: UInt(curve.uintValue) << 16)
        UIView.animate(withDuration: duration.doubleValue, delay: 0, options: options, animations: {
            let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            if self.view.window != nil {
                let windowKeyboardFrame = self.view.window!.convert(keyboardFrame, from: nil)
                let localKeyboardFrame = self.view.convert(windowKeyboardFrame, from: nil)
                let insetBottom = localKeyboardFrame.intersection(self.view.bounds).height
                
                var contentInsets = self.scrollView.contentInset
                contentInsets.bottom = insetBottom
                self.scrollView.contentInset = contentInsets
                
                var scrollIndicatorInsets = self.scrollView.scrollIndicatorInsets
                scrollIndicatorInsets.bottom = insetBottom
                self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
            }
            
        }, completion: nil)
    }
}
