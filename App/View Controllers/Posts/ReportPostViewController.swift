//  ReportPostViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress

final class ReportPostViewController: ViewController, UITextViewDelegate {
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
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction fileprivate func didTapSubmit() {
        if UserDefaults.standard.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        rootView.endEditing(true)
        
        let progressView = MRProgressOverlayView.showOverlayAdded(to: view.window, title: "Reporting…", mode: .indeterminate, animated: true)!
        Task {
            try? await ForumsClient.shared.report(post, nws: rootView.nwsSwitch.isOn, reason: rootView.commentTextView.text ?? "")
            progressView.dismiss(true)
            await dismiss(animated: true)
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        navigationItem.rightBarButtonItem?.isEnabled = (textView.text ?? "").count <= 960
    }
    
    fileprivate class RootView: UIView {
        let instructionLabel = UILabel()
        let nwsLabel = UILabel()
        let nwsSwitch = UISwitch()
        let commentFieldLabel = UILabel()
        let commentTextView = UITextView()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            instructionLabel.text = "Did this post break the forum rules? If so, please report it (limit 960 characters.)"
            instructionLabel.numberOfLines = 0
            addSubview(instructionLabel)
            
            nwsLabel.text = "Reported post contains NWS content"
            nwsLabel.numberOfLines = 0
            addSubview(nwsLabel)
            
            addSubview(nwsSwitch)
            
            commentFieldLabel.text = "Optional comments:"
            commentFieldLabel.numberOfLines = 0
            addSubview(commentFieldLabel)
            
            commentTextView.font = commentFieldLabel.font
            addSubview(commentTextView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            let availableArea = bounds.insetBy(dx: 8, dy: 8)
            instructionLabel.frame = availableArea
            instructionLabel.sizeToFit()
            
            nwsLabel.frame = availableArea
            nwsLabel.sizeToFit()
            nwsLabel.frame.origin.y = instructionLabel.frame.maxY + 10
            
            nwsSwitch.frame = availableArea
            nwsSwitch.sizeToFit()
            nwsSwitch.frame.origin.y = nwsLabel.frame.maxY + 10
            
            commentFieldLabel.frame = availableArea
            commentFieldLabel.sizeToFit()
            commentFieldLabel.frame.origin.y = nwsSwitch.frame.maxY + 10
            
            commentTextView.frame = availableArea
            commentTextView.sizeToFit()
            commentTextView.frame.origin.y = commentFieldLabel.frame.maxY + 10
            commentTextView.frame.size.width = availableArea.width
            commentTextView.frame.size.height = (availableArea.height - (commentTextView.frame.minY)) / 3
        }
    }
    
    fileprivate var rootView: RootView { return view as! RootView }
    
    override func loadView() {
        view = RootView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rootView.commentTextView.delegate = self
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        rootView.instructionLabel.textColor = theme["listTextColor"]
        rootView.commentFieldLabel.textColor = theme["listTextColor"]
        rootView.commentTextView.textColor = theme["listTextColor"]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        rootView.commentTextView.becomeFirstResponder()
    }
}
