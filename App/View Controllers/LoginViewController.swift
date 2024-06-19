//  LoginViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
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

    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorageOptional(Settings.userID) private var userID
    @FoilDefaultStorageOptional(Settings.username) private var username

    fileprivate enum State {
        case awaitingUsername
        case awaitingPassword
        case canAttemptLogin
        case attemptingLogin
        case failedLogin(Error)
    }
    
    fileprivate var state: State = .awaitingUsername {
        didSet {
            switch state {
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
            case .failedLogin(let error):
                activityIndicator.stopAnimating()
                let title: String
                let message: String
                if let error = error as? ServerError, case .banned = error {
                    // ServerError.banned has actually helpful info to report here.
                    title = error.localizedDescription
                    message = error.failureReason ?? ""
                } else {
                    title = String(localized: "Problem Logging In")
                    message = String(localized: "Double-check your username and password, then try again.")
                }
                let alert = UIAlertController(title: title, message: message, alertActions: [.ok {
                    self.state = .canAttemptLogin
                    self.passwordTextField.becomeFirstResponder()
                }])
                present(alert, animated: true)
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
    
    fileprivate func attemptToLogIn() {
        if case .canAttemptLogin = state { /* yay */ } else {
            assertionFailure("unexpected state: \(state)")
        }
        state = .attemptingLogin
        Task {
            do {
                let user = try await ForumsClient.shared.logIn(
                    username: usernameTextField.text ?? "",
                    password: passwordTextField.text ?? ""
                )
                canSendPrivateMessages = user.canReceivePrivateMessages
                userID = user.userID
                username = user.username
                completionBlock?(self)
            } catch {
                Log.e("Could not log in: \(error)")
                state = .failedLogin(error)
            }
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

private extension NSMutableAttributedString {

    /**
     Creates an attributed string by replacing instances of `%@` or `%n$@` in `format` with the appropriate element from `args`.

     It is a programmer error if `format` specifies an element that does not exist in `args`.

     - Warning: No format specifiers are supported other than `@` (and `%` to escape a percent sign).
     */
    convenience init(format: NSAttributedString, _ args: NSAttributedString...) {
        self.init(attributedString: format)

        func makeScanner(at index: String.Index) -> Scanner {
            let scanner = Scanner(string: string)
            scanner.caseSensitive = false
            scanner.charactersToBeSkipped = nil
            scanner.currentIndex = index
            return scanner
        }

        var scanner = makeScanner(at: string.startIndex)

        var unindexedArgs = args.makeIterator()

        while true {

            // Find next %
            _ = scanner.scanUpToString("%")
            let specifierStartIndex = scanner.currentIndex

            // If we didn't find one, we're done!
            guard scanner.scanString("%") != nil else { break }

            // Might just be a %-escaped %.
            if scanner.scanString("%") != nil {
                continue
            }

            let replacement: NSAttributedString
            if
                let i = scanner.scanInt(),
                scanner.scanString("$") != nil,
                scanner.scanString("@") != nil
            {
                // Format specifiers are 1-indexed.
                replacement = args[i - 1]
            }
            else if scanner.scanString("@") != nil {
                replacement = unindexedArgs.next()!
            }
            else {
                fatalError("unsupported format specifier in \(scanner.string) at index \(scanner.currentIndex)")
            }

            let specifierRange = NSRange(
                location: specifierStartIndex.utf16Offset(in: scanner.string),
                length: scanner.string.distance(from: specifierStartIndex, to: scanner.currentIndex))
            replaceCharacters(in: specifierRange, with: replacement)

            scanner = makeScanner(at: string.index(specifierStartIndex, offsetBy: replacement.length))
        }
    }
}
