//  CompositionInputAccessoryView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies
import UIKit

final class CompositionInputAccessoryView: UIInputView {
    private(set) weak var textView: UITextView?
    private let middleButtonContainer = UIStackView()
    private let smilieCommand: ShowSmilieKeyboardCommand
    private let autocloseCommand: CloseBBcodeTagCommand
    private var widthConstraints: [NSLayoutConstraint] = []
    private var heightConstraints: [NSLayoutConstraint] = []
    private var edgeConstraints: [NSLayoutConstraint] = []
    
    private lazy var smilieButton: KeyboardButton = {
        let button = KeyboardButton()
        button.setTitle(":-)", forState: .Normal)
        button.accessibilityLabel = "Toggle smilie keyboard"
        button.addTarget(self, action: #selector(CompositionInputAccessoryView.didTapSmilieButton), forControlEvents: .TouchUpInside)
        return button
    }()
    
    private lazy var middleButtons: [KeyboardButton] = {
        return ["[", "=", ":", "/", "]"].map { title in
            let button = KeyboardButton()
            button.setTitle(title, forState: .Normal)
            button.addTarget(self, action: #selector(CompositionInputAccessoryView.didPressSingleCharacterKey(_:)), forControlEvents: .TouchUpInside)
            return button
        }
    }()
    
    private lazy var autocloseButton: KeyboardButton = {
        let button = KeyboardButton()
        button.setTitle("[/..]", forState: .Normal)
        button.accessibilityLabel = "Close tag"
        button.setTitleColor(.grayColor(), forState: .Disabled)
        button.addTarget(self, action: #selector(CompositionInputAccessoryView.didTapAutocloseButton), forControlEvents: .TouchUpInside)
        return button
    }()
    
    var keyboardAppearance: UIKeyboardAppearance = .Default {
        didSet { updateColors() }
    }
    
    init(textView: UITextView) {
        self.textView = textView
        smilieCommand = ShowSmilieKeyboardCommand(textView: textView)
        autocloseCommand = CloseBBcodeTagCommand(textView: textView)
        
        let height = UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 66 : 38
        let frame = CGRect(x: 0, y: 0, width: 0, height: height)
        super.init(frame: frame, inputViewStyle: .Default)
        
        opaque = true
        
        KVOController.observe(autocloseCommand, keyPath: "enabled", options: [.Initial], typedBlock: { [weak self] (command, change) in
            self?.autocloseButton.enabled = command.enabled
            })
        
        smilieButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(smilieButton)
        
        middleButtonContainer.distribution = .FillEqually
        middleButtonContainer.alignment = .Center
        middleButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(middleButtonContainer)
        
        for button in middleButtons {
            middleButtonContainer.addArrangedSubview(button)
        }
        
        autocloseButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(autocloseButton)
        
        let allButtons = [smilieButton, autocloseButton] + middleButtons
        for button in allButtons {
            widthConstraints.append(button.widthAnchor.constraintEqualToConstant(40))
            heightConstraints.append(button.heightAnchor.constraintEqualToConstant(32))
        }
        (widthConstraints + heightConstraints).forEach { $0.active = true }
        
        edgeConstraints.append(smilieButton.leadingAnchor.constraintEqualToAnchor(leadingAnchor))
        edgeConstraints.append(trailingAnchor.constraintEqualToAnchor(autocloseButton.trailingAnchor))
        edgeConstraints.forEach { $0.active = true }
        
        smilieButton.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true
        autocloseButton.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true
        
        middleButtonContainer.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        middleButtonContainer.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        middleButtonContainer.bottomAnchor.constraintEqualToAnchor(bottomAnchor).active = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func didPressSingleCharacterKey(button: KeyboardButton) {
        guard let text = button.currentTitle else { return }
        UIDevice.currentDevice().playInputClick()
        textView?.insertText(text)
    }
    
    @objc private func didTapSmilieButton() {
        UIDevice.currentDevice().playInputClick()
        smilieCommand.execute()
    }
    
    @objc private func didTapAutocloseButton() {
        UIDevice.currentDevice().playInputClick()
        autocloseCommand.execute()
    }
    
    private func updateColors() {
        let backgroundColor: UIColor
        let titleColor: UIColor
        let normalBackgroundColor: UIColor
        let selectedBackgroundColor: UIColor
        let shadowColor: UIColor
        
        switch keyboardAppearance {
        case .Dark:
            backgroundColor = UIColor(white: 0.078, alpha: 1)
            titleColor = .whiteColor()
            normalBackgroundColor = UIColor(white: 0.353, alpha: 1)
            selectedBackgroundColor = UIColor(white: 0.149, alpha: 1)
            shadowColor = .blackColor()
            
        default:
            switch traitCollection.userInterfaceIdiom {
            case .Pad:
                backgroundColor = UIColor(red: 0.812, green: 0.824, blue: 0.835, alpha: 1)
            default:
                backgroundColor = UIColor(red: 0.863, green: 0.875, blue: 0.886, alpha: 1)
            }
            titleColor = .blackColor()
            normalBackgroundColor = UIColor(red: 0.988, green: 0.988, blue: 0.992, alpha: 1)
            selectedBackgroundColor = UIColor(red: 0.831, green: 0.839, blue: 0.847, alpha: 1)
            shadowColor = .grayColor()
        }
        
        self.backgroundColor = backgroundColor
        
        for button in [smilieButton, autocloseButton] + middleButtons {
            button.setTitleColor(titleColor, forState: .Normal)
            button.normalBackgroundColor = normalBackgroundColor
            button.selectedBackgroundColor = selectedBackgroundColor
            button.layer.shadowColor = shadowColor.CGColor
        }
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom else { return }
        
        let width: CGFloat
        let height: CGFloat
        let edge: CGFloat
        let between: CGFloat
        switch traitCollection.userInterfaceIdiom {
        case .Pad:
            width = 57
            height = 57
            edge = 5
            between = 12
            
        default:
            width = 40
            height = 32
            edge = 2
            between = 6
        }
        widthConstraints.forEach { $0.constant = width }
        heightConstraints.forEach { $0.constant = height }
        edgeConstraints.forEach { $0.constant = edge }
        middleButtonContainer.spacing = between
        
        updateColors()
    }
}

extension CompositionInputAccessoryView: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        return true
    }
}

private final class KeyboardButton: SmilieButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 22)
        
        layer.cornerRadius = 4
        layer.borderWidth = 0
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        
        accessibilityTraits &= ~UIAccessibilityTraitButton
        accessibilityTraits |= UIAccessibilityTraitKeyboardKey
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom else { return }
        
        if traitCollection.userInterfaceIdiom == .Phone {
            contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        } else {
            contentEdgeInsets = UIEdgeInsets()
        }
    }
}
