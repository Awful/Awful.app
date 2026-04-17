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

    private let modernToolbar: ModernBBcodeToolbar
    private let existingToolbar: CompositionInputAccessoryView

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews(modernHeight: CGFloat) {
        // Modern toolbar setup
        modernToolbar.translatesAutoresizingMaskIntoConstraints = false
        modernToolbar.onAction = { [weak self] action in
            self?.onToolbarAction?(action)
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
}

// MARK: - Audio Feedback

extension CompositionToolbarContainer: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        return true
    }
}
