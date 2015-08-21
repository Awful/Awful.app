//  CompositionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class CompositionViewController: AwfulViewController {
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nil, bundle: nil)
        restorationClass = self.dynamicType
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var title: String? {
        didSet {
            navigationItem.titleLabel.text = title
            navigationItem.titleLabel.sizeToFit()
        }
    }
    
    @objc private func didTapCancel() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    var textView: UITextView {
        return view as! UITextView
    }
    
    override func loadView() {
        let textView = CompositionTextView()
        textView.restorationIdentifier = "Composition text view"
        view = textView
        
        BBcodeBar = CompositionInputAccessoryView(textView: textView)
        textView.inputAccessoryView = BBcodeBar
    }
    
    private var keyboardAvoider: ScrollViewKeyboardAvoider?
    private var BBcodeBar: CompositionInputAccessoryView?
    private var menuTree: CompositionMenuTree?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keyboardAvoider = ScrollViewKeyboardAvoider(textView)
        menuTree = CompositionMenuTree(textView: textView)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        textView.textColor = theme["listTextColor"]
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        textView.keyboardAppearance = theme.keyboardAppearance
        BBcodeBar?.keyboardAppearance = theme.keyboardAppearance
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        textView.becomeFirstResponder()
        
        // Leave an escape hatch in case we were restored without an associated workspace. This can happen when a crash leaves old state information behind.
        if navigationItem.leftBarButtonItem == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapCancel")
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        textView.flashScrollIndicators()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.endEditing(true)
    }
}

extension CompositionViewController: UIViewControllerRestoration {
    class func viewControllerWithRestorationIdentifierPath(identifierComponents: [AnyObject], coder: NSCoder) -> UIViewController? {
        let composition = self.init()
        composition.restorationIdentifier = identifierComponents.last as! String?
        return composition
    }
}

final class CompositionTextView: UITextView, CompositionHidesMenuItems {
    var hidesBuiltInMenuItems: Bool = false
    
    override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
        if hidesBuiltInMenuItems {
            return false
        }
        
        return super.canPerformAction(action, withSender: sender)
    }
}
