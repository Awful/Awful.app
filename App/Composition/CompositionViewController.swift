//  CompositionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

final class CompositionViewController: ViewController {
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        restorationClass = type(of: self)
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
    
    @objc fileprivate func didTapCancel() {
        dismiss(animated: true, completion: nil)
    }
    
    func cancel(_ sender: UIKeyCommand) {
        self.didTapCancel()
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
    
    fileprivate var keyboardAvoider: ScrollViewKeyboardAvoider?
    fileprivate var BBcodeBar: CompositionInputAccessoryView?
    fileprivate var menuTree: CompositionMenuTree?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keyboardAvoider = ScrollViewKeyboardAvoider(textView)
        menuTree = CompositionMenuTree(textView: textView)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        textView.textColor = theme["listTextColor"]
        textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        textView.keyboardAppearance = theme.keyboardAppearance
        BBcodeBar?.keyboardAppearance = theme.keyboardAppearance
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        textView.becomeFirstResponder()
        
        // Leave an escape hatch in case we were restored without an associated workspace. This can happen when a crash leaves old state information behind.
        if navigationItem.leftBarButtonItem == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CompositionViewController.didTapCancel))
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        textView.flashScrollIndicators()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.endEditing(true)
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyInputEscape, modifierFlags: [], action: #selector(CompositionViewController.cancel(_:)), discoverabilityTitle: "Cancel"),
        ]
    }
}

extension CompositionViewController: UIViewControllerRestoration {
    class func viewController(withRestorationIdentifierPath identifierComponents: [Any], coder: NSCoder) -> UIViewController? {
        let composition = self.init()
        composition.restorationIdentifier = identifierComponents.last as! String?
        return composition
    }
}

final class CompositionTextView: UITextView, CompositionHidesMenuItems {
    var hidesBuiltInMenuItems: Bool = false
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if hidesBuiltInMenuItems {
            return false
        }
        
        return super.canPerformAction(action, withSender: sender)
    }
}
