//  CompositionViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import UIKit

final class CompositionViewController: ViewController {

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics

    private enum AttachmentViewLayout {
        static let previewHeight: CGFloat = 84
        static let editHeight: CGFloat = 120
        static let spacing: CGFloat = 8
        static let animationDuration: TimeInterval = 0.3
    }

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
        textViewTopConstraint = _textView.topAnchor.constraint(equalTo: attachmentPreviewView.bottomAnchor, constant: AttachmentViewLayout.spacing)

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

        toolbarContainer = CompositionToolbarContainer(textView: _textView)
        toolbarContainer?.onToolbarAction = { [weak self] action in
            self?.handleToolbarAction(action)
        }
        _textView.inputAccessoryView = toolbarContainer
    }

    fileprivate var keyboardAvoider: ScrollViewKeyboardAvoider?
    fileprivate var toolbarContainer: CompositionToolbarContainer?
    fileprivate var menuTree: CompositionMenuTree?
    private weak var currentDraft: (NSObject & ReplyDraft)?

    /// Called when attachment processing starts or finishes. `true` means processing is in progress.
    var onAttachmentProcessingChanged: ((Bool) -> Void)?

    func setDraft(_ draft: NSObject & ReplyDraft) {
        menuTree?.draft = draft
        currentDraft = draft
        updateAttachmentPreview()
    }

    func showResizingPlaceholder() {
        attachmentPreviewView.showResizingPlaceholder()
        onAttachmentProcessingChanged?(true)
        updateAttachmentViewVisibility(
            showPreview: true, previewHeight: AttachmentViewLayout.previewHeight,
            showEdit: false, editHeight: 0,
            anchorTextViewTo: attachmentPreviewView.bottomAnchor
        )
    }

    private func updateAttachmentPreview() {
        guard let draft = currentDraft else {
            hideAllAttachmentViews()
            return
        }

        // If a new attachment has been selected (for new reply, add-to-edit, or replace), show its preview
        if let attachment = draft.forumAttachment {
            showAttachmentPreview(with: attachment)
            return
        }

        // For edits with an existing attachment (and no replacement selected), show the edit view
        if let editDraft = draft as? EditReplyDraft,
           let existingFilename = editDraft.existingAttachmentFilename {
            showAttachmentEditView(filename: existingFilename, filesize: editDraft.existingAttachmentFilesize, image: editDraft.existingAttachmentImage)
            return
        }

        hideAllAttachmentViews()
    }

    private func showAttachmentPreview(with attachment: ForumAttachment) {
        attachmentPreviewView.configure(with: attachment)
        updateAttachmentViewVisibility(
            showPreview: true, previewHeight: AttachmentViewLayout.previewHeight,
            showEdit: false, editHeight: 0,
            anchorTextViewTo: attachmentPreviewView.bottomAnchor
        )
    }

    private func showAttachmentEditView(filename: String, filesize: String?, image: UIImage? = nil) {
        attachmentEditView.configure(filename: filename, filesize: filesize, image: image)
        updateAttachmentViewVisibility(
            showPreview: false, previewHeight: 0,
            showEdit: true, editHeight: AttachmentViewLayout.editHeight,
            anchorTextViewTo: attachmentEditView.bottomAnchor
        )
    }

    private func hideAllAttachmentViews() {
        updateAttachmentViewVisibility(
            showPreview: false, previewHeight: 0,
            showEdit: false, editHeight: 0,
            anchorTextViewTo: attachmentPreviewView.bottomAnchor
        )
    }

    private func updateAttachmentViewVisibility(
        showPreview: Bool, previewHeight: CGFloat,
        showEdit: Bool, editHeight: CGFloat,
        anchorTextViewTo anchor: NSLayoutYAxisAnchor
    ) {
        attachmentPreviewView.isHidden = !showPreview
        attachmentPreviewHeightConstraint.constant = previewHeight

        attachmentEditView.isHidden = !showEdit
        attachmentEditHeightConstraint.constant = editHeight

        updateTextViewConstraint(anchoredTo: anchor)
    }

    private func updateTextViewConstraint(anchoredTo anchor: NSLayoutYAxisAnchor, constant: CGFloat = AttachmentViewLayout.spacing) {
        textViewTopConstraint.isActive = false
        textViewTopConstraint = _textView.topAnchor.constraint(equalTo: anchor, constant: constant)
        textViewTopConstraint.isActive = true

        UIView.animate(withDuration: AttachmentViewLayout.animationDuration) {
            self.view.layoutIfNeeded()
        }
    }

    private func removeAttachment() {
        currentDraft?.forumAttachment = nil
        updateAttachmentPreview()
    }

    private func handleAttachmentEditAction(_ action: AttachmentEditView.AttachmentAction) {
        guard let editDraft = currentDraft as? EditReplyDraft else { return }

        switch action {
        case .keep:
            editDraft.attachmentAction = .keep
        case .delete:
            editDraft.attachmentAction = .delete
        case .replace:
            menuTree?.pickImageForAttachment()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        keyboardAvoider = ScrollViewKeyboardAvoider(textView)
        menuTree = CompositionMenuTree(textView: textView)
        menuTree?.onAttachmentChanged = { [weak self] in
            self?.onAttachmentProcessingChanged?(false)
            self?.updateAttachmentPreview()
        }
        menuTree?.onResizingStarted = { [weak self] in
            self?.showResizingPlaceholder()
        }
        menuTree?.onShowURLPrompt = { [weak self] in
            self?.showURLPrompt()
        }
        menuTree?.onShowVideoPrompt = { [weak self] in
            self?.showVideoPrompt()
        }
        menuTree?.onShowImageOptions = { [weak self] in
            self?.showImageOptions()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        textView.backgroundColor = theme["backgroundColor"]
        textView.textColor = theme["listTextColor"]
        textView.font = UIFont.preferredFontForTextStyle(.body, sizeAdjustment: -0.5, weight: .regular)
        textView.keyboardAppearance = theme.keyboardAppearance
        toolbarContainer?.keyboardAppearance = theme.keyboardAppearance
        toolbarContainer?.fontName = theme["listFontName"]

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
    
    // MARK: - Toolbar Actions

    private func handleToolbarAction(_ action: ModernToolbarAction) {
        switch action {
        case .url:
            showURLPrompt()
        case .image:
            showImageOptions()
        case .format(let option):
            let helper = BBcodeTagHelper(textView: textView)
            helper.applyFormat(option)
        case .video:
            showVideoPrompt()
        }
    }

    // MARK: - URL and Video Prompts

    func showURLPrompt() {
        let alert = UIAlertController(title: "Insert Link", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "URL (e.g., https://example.com)"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addTextField { [weak self] textField in
            textField.placeholder = "Display text (optional)"
            if let selection = self?.textView.selectedTextRange,
               let selectedText = self?.textView.text(in: selection),
               !selectedText.isEmpty {
                textField.text = selectedText
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            let url = alert.textFields?[0].text ?? ""
            let displayText = alert.textFields?[1].text ?? ""
            self?.insertURLTag(url: url, displayText: displayText)
        })

        present(alert, animated: true)
    }

    private func insertURLTag(url: String, displayText: String) {
        guard !url.isEmpty else { return }
        let helper = BBcodeTagHelper(textView: textView)
        if displayText.isEmpty {
            helper.insertText("[url]\(url)[/url]")
        } else {
            helper.insertText("[url=\(url)]\(displayText)[/url]")
        }
    }

    func showVideoPrompt() {
        let alert = UIAlertController(title: "Insert Video", message: "Supported: YouTube, Vimeo, TikTok, CNN, Yahoo, FOXNews", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Video URL"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            guard let urlString = alert.textFields?[0].text, !urlString.isEmpty else { return }
            self?.insertVideoTag(urlString: urlString)
        })

        present(alert, animated: true)
    }

    private func insertVideoTag(urlString: String) {
        let helper = BBcodeTagHelper(textView: textView)
        if let url = URL(string: urlString),
           let normalizedURL = BBcodeTagHelper.videoTagURL(for: url) {
            helper.insertText("[video]\(normalizedURL.absoluteString)[/video]")
        } else {
            helper.insertText("[video]\(urlString)[/video]")
        }
    }

    // MARK: - Image Options

    func showImageOptions() {
        let alert = UIAlertController(title: "Insert Image", message: nil, preferredStyle: .actionSheet)

        if BBcodeTagHelper.clipboardHasURL {
            alert.addAction(UIAlertAction(title: "Paste URL from Clipboard", style: .default) { [weak self] _ in
                guard let self = self else { return }
                if let url = UIPasteboard.general.coercedURL {
                    let helper = BBcodeTagHelper(textView: self.textView)
                    helper.insertText("[img]\(url.absoluteString)[/img]")
                }
            })
        }

        let canAttachInEdit = (menuTree?.draft as? EditReplyDraft)?.canAddAttachment ?? false
        if let menuTree = menuTree, menuTree.imgurUploadsEnabled || menuTree.draft is NewReplyDraft || canAttachInEdit {
            alert.addAction(UIAlertAction(title: "From Library", style: .default) { [weak self] _ in
                self?.menuTree?.showImagePicker(.photoLibrary)
            })
        }

        alert.addAction(UIAlertAction(title: "Enter URL", style: .default) { [weak self] _ in
            self?.showImagePrompt()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = textView
            popover.sourceRect = textView.selectedRect ?? textView.bounds
        }

        present(alert, animated: true)
    }

    func showImagePrompt() {
        let alert = UIAlertController(title: "Insert Image", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Image URL"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            if let clipboardURL = UIPasteboard.general.coercedURL {
                textField.text = clipboardURL.absoluteString
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Insert", style: .default) { [weak self] _ in
            guard let urlString = alert.textFields?[0].text, !urlString.isEmpty else { return }
            let helper = BBcodeTagHelper(textView: self?.textView ?? UITextView())
            helper.insertText("[img]\(urlString)[/img]")
        })

        present(alert, animated: true)
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
