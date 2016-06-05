//  ReportPostViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress

final class ReportPostViewController: ViewController {
    private let post: Post
    
    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
        
        title = "Report Post"
        modalPresentationStyle = .FormSheet
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(didTapCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .Done, target: self, action: #selector(didTapSubmit))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction @objc private func didTapCancel() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction @objc private func didTapSubmit() {
        rootView.endEditing(true)
        
        let progressView = MRProgressOverlayView.showOverlayAddedTo(view.window, title: "Reporting…", mode: .Indeterminate, animated: true)
        AwfulForumsClient.sharedClient().reportPost(post, withReason: rootView.commentTextField.text) { [weak self] error in
            progressView.dismiss(true)
            
            if let error = error {
                let alert = UIAlertController(networkError: error, handler: nil)
                self?.presentViewController(alert, animated: true, completion: nil)
            } else {
                self?.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }
    
    @IBAction @objc private func commentTextFieldDidChange(textField: UITextField) {
        navigationItem.rightBarButtonItem?.enabled = (textField.text ?? "").characters.count <= 60
    }
    
    private class RootView: UIView {
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
    
    private var rootView: RootView { return view as! RootView }
    
    override func loadView() {
        view = RootView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rootView.commentTextField.addTarget(self, action: #selector(commentTextFieldDidChange), forControlEvents: .ValueChanged)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        rootView.instructionLabel.textColor = theme["listTextColor"] as UIColor?
        rootView.commentTextField.textColor = theme["listTextColor"] as UIColor?
        rootView.commentTextField.attributedPlaceholder = NSAttributedString(string: "Optional comment", attributes: [
            NSForegroundColorAttributeName: theme["placeholderTextColor"] as UIColor!])
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        rootView.commentTextField.becomeFirstResponder()
    }
}
