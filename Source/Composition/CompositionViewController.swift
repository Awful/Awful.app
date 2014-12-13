//  CompositionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class CompositionViewController: AwfulViewController {
    override init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var textView: UITextView {
        return view as UITextView
    }
    
    override func loadView() {
        let textView = CompositionTextView()
        view = textView
    }
    
    private var keyboardAvoider: ScrollViewKeyboardAvoider?
    private var BBcodeBar: CompositionInputAccessoryView?
    private var menuTree: CompositionMenuTree?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keyboardAvoider = ScrollViewKeyboardAvoider(textView)
        BBcodeBar = CompositionInputAccessoryView(textView: textView)
        textView.inputAccessoryView = BBcodeBar
        menuTree = CompositionMenuTree(textView: textView)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        textView.textColor = theme["listTextColor"] as UIColor?
        textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        textView.keyboardAppearance = theme.keyboardAppearance
        BBcodeBar?.keyboardAppearance = theme.keyboardAppearance
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        textView.becomeFirstResponder()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        textView.flashScrollIndicators()
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
