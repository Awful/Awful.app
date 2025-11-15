//  CompositionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import UIKit

final class CompositionViewController: ViewController {

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics

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
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss(animated: true)
    }

    @objc func cancel(_ sender: UIKeyCommand) {
        self.didTapCancel()
    }

    private var _textView: CompositionTextView!
    var textView: UITextView {
        return _textView
    }

    private let containerView = UIView()
    private let attachmentPreviewView = AttachmentPreviewView()
    private let attachmentEditView = AttachmentEditView()
    private var attachmentPreviewHeightConstraint: NSLayoutConstraint!
    private var attachmentEditHeightConstraint: NSLayoutConstraint!
    private var textViewTopConstraint: NSLayoutConstraint!

    override func loadView() {
        view = containerView

        _textView = CompositionTextView()
        _textView.restorationIdentifier = "Composition text view"
        _textView.translatesAutoresizingMaskIntoConstraints = false

        attachmentPreviewView.translatesAutoresizingMaskIntoConstraints = false
        attachmentPreviewView.isHidden = true
        attachmentPreviewView.onRemove = { [weak self] in
            self?.removeAttachment()
        }

        attachmentEditView.translatesAutoresizingMaskIntoConstraints = false
        attachmentEditView.isHidden = true
        attachmentEditView.onActionChanged = { [weak self] action in
            self?.handleAttachmentEditAction(action)
        }

        containerView.addSubview(attachmentPreviewView)
        containerView.addSubview(attachmentEditView)
        containerView.addSubview(_textView)

        attachmentPreviewHeightConstraint = attachmentPreviewView.heightAnchor.constraint(equalToConstant: 0)
        attachmentEditHeightConstraint = attachmentEditView.heightAnchor.constraint(equalToConstant: 0)

        // Default: text view top anchors to preview view bottom (which starts at height 0)
        textViewTopConstraint = _textView.topAnchor.constraint(equalTo: attachmentPreviewView.bottomAnchor, constant: 8)

        NSLayoutConstraint.activate([
            attachmentPreviewView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 8),
            attachmentPreviewView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            attachmentPreviewView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            attachmentPreviewHeightConstraint,

            attachmentEditView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 8),
            attachmentEditView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            attachmentEditView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            attachmentEditHeightConstraint,

            textViewTopConstraint,
            _textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            _textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            _textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        BBcodeBar = CompositionInputAccessoryView(textView: _textView)
        _textView.inputAccessoryView = BBcodeBar
    }

    fileprivate var keyboardAvoider: ScrollViewKeyboardAvoider?
    fileprivate var BBcodeBar: CompositionInputAccessoryView?
    fileprivate var menuTree: CompositionMenuTree?
    private weak var currentDraft: (NSObject & ReplyDraft)?

    func setDraft(_ draft: NSObject & ReplyDraft) {
        menuTree?.draft = draft
        currentDraft = draft
        updateAttachmentPreview()
    }

    func showResizingPlaceholder() {
        attachmentPreviewView.showResizingPlaceholder()
        attachmentPreviewView.isHidden = false
        attachmentPreviewHeightConstraint.constant = 84

        attachmentEditView.isHidden = true
        attachmentEditHeightConstraint.constant = 0

        updateTextViewConstraint(anchoredTo: attachmentPreviewView.bottomAnchor)
    }

    private func updateAttachmentPreview() {
        guard let draft = currentDraft else {
            hideAllAttachmentViews()
            return
        }

        // For edits, show existing attachment info if available
        if let editDraft = draft as? EditReplyDraft {
            if let existingFilename = editDraft.existingAttachmentFilename {
                showAttachmentEditView(filename: existingFilename, filesize: editDraft.existingAttachmentFilesize, image: editDraft.existingAttachmentImage)
                return
            }
        }

        // For new posts, show preview if attachment is set
        if let attachment = draft.forumAttachment {
            showAttachmentPreview(with: attachment)
        } else {
            hideAllAttachmentViews()
        }
    }

    private func showAttachmentPreview(with attachment: ForumAttachment) {
        attachmentEditView.isHidden = true
        attachmentEditHeightConstraint.constant = 0

        attachmentPreviewView.configure(with: attachment)
        attachmentPreviewView.isHidden = false
        attachmentPreviewHeightConstraint.constant = 84

        updateTextViewConstraint(anchoredTo: attachmentPreviewView.bottomAnchor)
    }

    private func showAttachmentEditView(filename: String, filesize: String?, image: UIImage? = nil) {
        attachmentPreviewView.isHidden = true
        attachmentPreviewHeightConstraint.constant = 0

        attachmentEditView.configure(filename: filename, filesize: filesize, image: image)
        attachmentEditView.isHidden = false
        attachmentEditHeightConstraint.constant = 120

        updateTextViewConstraint(anchoredTo: attachmentEditView.bottomAnchor)
    }

    private func hideAllAttachmentViews() {
        attachmentPreviewView.isHidden = true
        attachmentPreviewHeightConstraint.constant = 0

        attachmentEditView.isHidden = true
        attachmentEditHeightConstraint.constant = 0

        updateTextViewConstraint(anchoredTo: attachmentPreviewView.bottomAnchor)
    }

    private func updateTextViewConstraint(anchoredTo anchor: NSLayoutYAxisAnchor, constant: CGFloat = 8) {
        textViewTopConstraint.isActive = false
        textViewTopConstraint = _textView.topAnchor.constraint(equalTo: anchor, constant: constant)
        textViewTopConstraint.isActive = true

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func removeAttachment() {
        currentDraft?.forumAttachment = nil
        hideAllAttachmentViews()
    }

    private func handleAttachmentEditAction(_ action: AttachmentEditView.AttachmentAction) {
        guard let editDraft = currentDraft as? EditReplyDraft else { return }

        editDraft.attachmentAction = (action == .keep) ? .keep : .delete
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardAvoider = ScrollViewKeyboardAvoider(textView)
        menuTree = CompositionMenuTree(textView: textView)
        menuTree?.onAttachmentChanged = { [weak self] in
            self?.updateAttachmentPreview()
        }
        menuTree?.onResizingStarted = { [weak self] in
            self?.showResizingPlaceholder()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        textView.backgroundColor = theme["backgroundColor"]
        textView.textColor = theme["listTextColor"]
        textView.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: -0.5, weight: .regular)
        textView.keyboardAppearance = theme.keyboardAppearance
        BBcodeBar?.keyboardAppearance = theme.keyboardAppearance

        // Theme the attachment cards
        let listTextColor: UIColor? = theme["listTextColor"]
        let borderColor: UIColor? = theme["listSecondaryTextColor"]

        attachmentPreviewView.backgroundColor = theme["backgroundColor"]
        attachmentPreviewView.layer.borderColor = borderColor?.cgColor
        attachmentPreviewView.layer.borderWidth = 1
        attachmentPreviewView.updateTextColor(listTextColor)

        attachmentEditView.backgroundColor = theme["backgroundColor"]
        attachmentEditView.layer.borderColor = borderColor?.cgColor
        attachmentEditView.layer.borderWidth = 1
        attachmentEditView.updateTextColor(listTextColor)
        attachmentEditView.updateSegmentedControlColors(selectedColor: theme["tabBarIconSelectedColor"])
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
            UIKeyCommand(action: #selector(cancel(_:)), input: UIKeyCommand.inputEscape, discoverabilityTitle: "Cancel"),
        ]
    }
}

extension CompositionViewController: UIViewControllerRestoration {
    class func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        let composition = self.init()
        composition.restorationIdentifier = identifierComponents.last 
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
