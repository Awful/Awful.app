//  LoginViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MiniOnePassword
import UIKit

private let Log = Logger.get()

private let lostPasswordURL = URL(string: "https://forums.somethingawful.com/account.php?action=lostpw")!
private let privacyPolicyURL = URL(string: "https://awfulapp.com/privacy-policy/")!
private let termsOfServiceURL = URL(string: "https://www.somethingawful.com/forum-rules/forum-rules/")!

class LoginViewController: ViewController {
    var completionBlock: ((LoginViewController) -> Void)?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var nextBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var consentToTermsTextView: UITextView!
    
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
                let alert = UIAlertController(title: "Problem Logging In", message: "Double-check your username and password, then try again.") {
                    self.state = .canAttemptLogin
                    self.passwordTextField.becomeFirstResponder()
                }
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    class func newFromStoryboard() -> LoginViewController {
        return UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! LoginViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Can't set this in the storyboard for some reason.
        nextBarButtonItem.isEnabled = false

        onePasswordButton.setImage(UIImage(named: "onepassword-button"), for: .normal)
        
        if !OnePassword.isAvailable {
            onePasswordButton.removeFromSuperview()
            view.addConstraints(onePasswordUnavailableConstraints)
        }
        
        consentToTermsTextView.attributedText = {
            let format = NSAttributedString(string: LocalizedString("login.consent-to-terms.full-text"))
            let privacyPolicy = NSAttributedString(
                string: LocalizedString("login.consent-to-terms.privacy-policy"),
                attributes: [.link: privacyPolicyURL])
            let termsOfService = NSAttributedString(
                string: LocalizedString("login.consent-to-terms.terms-of-service"),
                attributes: [.link: termsOfServiceURL])
            let attributedText = NSMutableAttributedString(format: format, privacyPolicy, termsOfService)
            attributedText.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: NSRange(location: 0, length: attributedText.length))
            return attributedText
        }()

        consentToTermsTextView.textColor = .label
        
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
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
    
    @IBAction func didTapOnePassword(_ sender: UIButton) {
        view.endEditing(true)

        OnePassword.findLogin(
            urlString: "forums.somethingawful.com",
            presentingViewController: self,
            sender: .view(sender),
            completion: { result in
                switch result {
                case let .success(loginInfo):
                    self.usernameTextField.text = loginInfo.username
                    self.passwordTextField.text = loginInfo.password
                    self.state = .canAttemptLogin

                case .failure(.userCancelled):
                    break

                case let .failure(error):
                    Log.e("1Password extension failed: \(error)")
                }
        })
    }
    
    fileprivate func attemptToLogIn() {
        assert(state == .canAttemptLogin, "unexpected state")
        state = .attemptingLogin
        ForumsClient.shared.logIn(username: usernameTextField.text ?? "",
                                  password: passwordTextField.text ?? "")
            .done { user in
                UserDefaults.standard.loggedInUserCanSendPrivateMessages = user.canReceivePrivateMessages
                UserDefaults.standard.loggedInUserID = user.userID
                UserDefaults.standard.loggedInUsername = user.username
                
                self.completionBlock?(self)
            }
            .catch { error in
                self.state = .failedLogin
        }
    }
    
    @IBAction func didTapForgetPassword() {
        UIApplication.shared.open(lostPasswordURL)
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

extension LoginViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange) -> Bool {
        UIApplication.shared.open(url)
        return false
    }
}

extension LoginViewController {
    @objc fileprivate func keyboardWillChangeFrame(_ notification: Notification) {
        // For whatever insane reason, iOS9 gives you keyboard events for things that happen in extensions.
        // Check to make sure the keyboard is actually "ours", because `self.view.window` is apparently nil if 1Password is using the keyboard.
        let isLocal = notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool
        if (isLocal != nil && isLocal == false) {
            return;
        }
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber
        let options = UIView.AnimationOptions(rawValue: UInt(curve.uintValue) << 16)
        UIView.animate(withDuration: duration.doubleValue, delay: 0, options: options, animations: {
            let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            if self.view.window != nil {
                let windowKeyboardFrame = self.view.window!.convert(keyboardFrame, from: nil)
                let localKeyboardFrame = self.view.convert(windowKeyboardFrame, from: nil)
                let insetBottom = localKeyboardFrame.intersection(self.view.bounds).height

                self.scrollView.contentInset.bottom = insetBottom
                self.scrollView.verticalScrollIndicatorInsets.bottom = insetBottom
            }
            
        }, completion: nil)
    }
}
