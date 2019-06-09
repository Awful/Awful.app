//  ReportPostViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress

final class ReportPostViewController: ViewController {
    fileprivate let post: Post
    
    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
        
        title = "Report Post"
        modalPresentationStyle = .formSheet
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(didTapSubmit))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction @objc fileprivate func didTapCancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction @objc fileprivate func didTapSubmit() {
        rootView.endEditing(true)
        
        let progressView = MRProgressOverlayView.showOverlayAdded(to: view.window, title: "Reporting…", mode: .indeterminate, animated: true)!
        ForumsClient.shared.report(post, reason: rootView.commentTextField.text ?? "")
            .done { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
            .catch { [weak self] error in
                let alert = UIAlertController(networkError: error)
                self?.present(alert, animated: true)
            }
            .finally {
                progressView.dismiss(true)
        }
    }
    
    @IBAction @objc fileprivate func commentTextFieldDidChange(_ textField: UITextField) {
        navigationItem.rightBarButtonItem?.isEnabled = (textField.text ?? "").count <= 60
    }
    
    fileprivate class RootView: UIView {
        let instructionLabel = UILabel()
        let commentTextField = UITextField()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            instructionLabel.text = "Did this post break the forum rules? If so, please report it."
            instructionLabel.numberOfLines = 0
            addSubview(instructionLabel)
            
            commentTextField.placeholder = "Optional comments"
            addSubview(commentTextField)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            let availableArea = bounds.insetBy(dx: 8, dy: 8)
            instructionLabel.frame = availableArea
            instructionLabel.sizeToFit()
            commentTextField.frame = availableArea
            commentTextField.sizeToFit()
            commentTextField.frame.origin.y = instructionLabel.frame.maxY + 10
            commentTextField.frame.size.width = availableArea.width
        }
    }
    
    fileprivate var rootView: RootView { return view as! RootView }
    
    override func loadView() {
        view = RootView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rootView.commentTextField.addTarget(self, action: #selector(commentTextFieldDidChange), for: .valueChanged)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        rootView.instructionLabel.textColor = theme["listTextColor"]
        rootView.commentTextField.textColor = theme["listTextColor"]
        rootView.commentTextField.attributedPlaceholder = NSAttributedString(string: "Optional comment", attributes: [
            .foregroundColor: theme[color: "placeholderTextColor"] ?? .black])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        rootView.commentTextField.becomeFirstResponder()
    }
}
