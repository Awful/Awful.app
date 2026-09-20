//  CompositionToolbarContainer.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Container that stacks the modern BBcode toolbar above the existing BBcode bar
final class CompositionToolbarContainer: UIInputView {

    // MARK: - Properties

    fileprivate(set) weak var textView: UITextView?

    /// Callback for when a toolbar action is triggered
    var onToolbarAction: ((ModernToolbarAction) -> Void)?

    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            existingToolbar.keyboardAppearance = keyboardAppearance
            updateModernToolbarAppearance()
        }
    }

    var fontName: String? {
        didSet {
            modernToolbar.fontName = fontName
        }
    }

    /// Outline for the modern toolbar's blur buttons; see `ModernBBcodeToolbar.strokeColor`.
    var strokeColor: UIColor? {
        didSet {
            modernToolbar.strokeColor = strokeColor
        }
    }

    /// Adds a Poll button to the modern toolbar. Only the new thread composer sets this.
    var showsPollButton: Bool {
        get { modernToolbar.showsPollButton }
        set { modernToolbar.showsPollButton = newValue }
    }

    /// Marks the Poll button to show a poll is already attached.
    var pollIsAttached: Bool {
        get { modernToolbar.pollIsAttached }
        set { modernToolbar.pollIsAttached = newValue }
    }

    /// Adds a Specs button to the modern toolbar. Only the feedback-thread reply composer sets this.
    var showsSpecsButton: Bool {
        get { modernToolbar.showsSpecsButton }
        set { modernToolbar.showsSpecsButton = newValue }
    }

    private let modernToolbar: ModernBBcodeToolbar
    private let existingToolbar: CompositionInputAccessoryView
    private var keyboardFrameObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(textView: UITextView) {
        self.textView = textView
        self.modernToolbar = ModernBBcodeToolbar()
        self.existingToolbar = CompositionInputAccessoryView(textView: textView)

        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let modernHeight: CGFloat = isIPad ? 52 : 44
        let existingHeight: CGFloat = isIPad ? 66 : 38
        let totalHeight = modernHeight + existingHeight

        let frame = CGRect(x: 0, y: 0, width: 0, height: totalHeight)
        super.init(frame: frame, inputViewStyle: .keyboard)

        setupViews(modernHeight: modernHeight)

        keyboardFrameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.keyboardDidChangeFrame(note)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyboardFrameObserver {
            NotificationCenter.default.removeObserver(keyboardFrameObserver)
        }
    }

    // MARK: - Setup

    private func setupViews(modernHeight: CGFloat) {
        // Modern toolbar setup
        modernToolbar.translatesAutoresizingMaskIntoConstraints = false
        modernToolbar.onAction = { [weak self] action in
            self?.onToolbarAction?(action)
        }
        modernToolbar.onToggleKeyboard = { [weak self] in
            guard let self, let textView = self.textView, !self.isKeyboardMinimizedBySystem else { return }
            textView.setKeyboardMinimized(!textView.isKeyboardMinimized)
            self.syncKeyboardToggle()
        }
        addSubview(modernToolbar)

        // Existing toolbar setup
        existingToolbar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(existingToolbar)

        NSLayoutConstraint.activate([
            // Modern toolbar at top
            modernToolbar.topAnchor.constraint(equalTo: topAnchor),
            modernToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            modernToolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            modernToolbar.heightAnchor.constraint(equalToConstant: modernHeight),

            // Existing toolbar below
            existingToolbar.topAnchor.constraint(equalTo: modernToolbar.bottomAnchor),
            existingToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            existingToolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            existingToolbar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateModernToolbarAppearance() {
        modernToolbar.keyboardAppearance = keyboardAppearance
    }

    // MARK: - Keyboard toggle

    /// Whether iOS has collapsed the keyboard on its own because a hardware keyboard is connected.
    private var isKeyboardMinimizedBySystem = false {
        didSet {
            if isKeyboardMinimizedBySystem != oldValue { syncKeyboardToggle() }
        }
    }

    /// With a hardware keyboard connected, iOS collapses the software keyboard to just this
    /// accessory view on its own, and nothing public brings it back (the user has the keyboard's
    /// Eject key for that). Spot that from the keyboard frame so the toggle can show the state
    /// without pretending to change it.
    ///
    /// iOS describes that state two ways: a keyboard no taller than this accessory view, or (on
    /// first presentation) a zero-height frame parked at the bottom of the screen. Either way this
    /// accessory view is on screen, which is what tells it apart from a keyboard that's gone.
    private func keyboardDidChangeFrame(_ note: Notification) {
        guard
            let textView,
            window != nil,
            let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }
        if let isLocal = note.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool, !isLocal { return }

        let safeAreaBottom = textView.window?.safeAreaInsets.bottom ?? 0
        let accessoryOnlyHeight = bounds.height + safeAreaBottom
        let minimizedByFrame = endFrame.height <= accessoryOnlyHeight + 1
        isKeyboardMinimizedBySystem = minimizedByFrame && !textView.isKeyboardMinimized
    }

    /// Matches the toggle's glyph to the text view's actual state. The keyboard can change under
    /// us (the legacy smilie keyboard replaces the input view; the composer resets it when it
    /// disappears), and every such change reinstalls this accessory view.
    private func syncKeyboardToggle() {
        let minimizedByUs = textView?.isKeyboardMinimized ?? false
        modernToolbar.isKeyboardMinimized = minimizedByUs || isKeyboardMinimizedBySystem
        modernToolbar.isKeyboardToggleEnabled = !isKeyboardMinimizedBySystem
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            syncKeyboardToggle()
        }
    }
}

// MARK: - Audio Feedback

extension CompositionToolbarContainer: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        return true
    }
}
