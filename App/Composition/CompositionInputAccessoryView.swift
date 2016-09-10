//  CompositionInputAccessoryView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies
import UIKit

final class CompositionInputAccessoryView: UIInputView {
    fileprivate(set) weak var textView: UITextView?
    fileprivate let middleButtonContainer = UIStackView()
    fileprivate let smilieCommand: ShowSmilieKeyboardCommand
    fileprivate let autocloseCommand: CloseBBcodeTagCommand
    fileprivate var widthConstraints: [NSLayoutConstraint] = []
    fileprivate var heightConstraints: [NSLayoutConstraint] = []
    fileprivate var edgeConstraints: [NSLayoutConstraint] = []
    
    fileprivate lazy var smilieButton: KeyboardButton = {
        let button = KeyboardButton()
        button.setTitle(":-)", for: UIControlState())
        button.accessibilityLabel = "Toggle smilie keyboard"
        button.addTarget(self, action: #selector(CompositionInputAccessoryView.didTapSmilieButton), for: .touchUpInside)
        return button
    }()
    
    fileprivate lazy var middleButtons: [KeyboardButton] = {
        return ["[", "=", ":", "/", "]"].map { title in
            let button = KeyboardButton()
            button.setTitle(title, for: UIControlState())
            button.addTarget(self, action: #selector(CompositionInputAccessoryView.didPressSingleCharacterKey(_:)), for: .touchUpInside)
            return button
        }
    }()
    
    fileprivate lazy var autocloseButton: KeyboardButton = {
        let button = KeyboardButton()
        button.setTitle("[/..]", for: UIControlState())
        button.accessibilityLabel = "Close tag"
        button.setTitleColor(.gray, for: .disabled)
        button.addTarget(self, action: #selector(CompositionInputAccessoryView.didTapAutocloseButton), for: .touchUpInside)
        return button
    }()
    
    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet { updateColors() }
    }
    
    init(textView: UITextView) {
        self.textView = textView
        smilieCommand = ShowSmilieKeyboardCommand(textView: textView)
        autocloseCommand = CloseBBcodeTagCommand(textView: textView)
        
        let height = UIDevice.current.userInterfaceIdiom == .pad ? 66 : 38
        let frame = CGRect(x: 0, y: 0, width: 0, height: height)
        super.init(frame: frame, inputViewStyle: .default)
        
        isOpaque = true
        
        kvoController.observe(autocloseCommand, keyPath: "enabled", options: [.initial], typedBlock: { [weak self] (command, change) in
            self?.autocloseButton.isEnabled = command.enabled
            })
        
        smilieButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(smilieButton)
        
        middleButtonContainer.distribution = .fillEqually
        middleButtonContainer.alignment = .center
        middleButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(middleButtonContainer)
        
        for button in middleButtons {
            middleButtonContainer.addArrangedSubview(button)
        }
        
        autocloseButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(autocloseButton)
        
        let allButtons = [smilieButton, autocloseButton] + middleButtons
        for button in allButtons {
            widthConstraints.append(button.widthAnchor.constraint(equalToConstant: 40))
            heightConstraints.append(button.heightAnchor.constraint(equalToConstant: 32))
        }
        (widthConstraints + heightConstraints).forEach { $0.isActive = true }
        
        edgeConstraints.append(smilieButton.leadingAnchor.constraint(equalTo: leadingAnchor))
        edgeConstraints.append(trailingAnchor.constraint(equalTo: autocloseButton.trailingAnchor))
        edgeConstraints.forEach { $0.isActive = true }
        
        smilieButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        autocloseButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        middleButtonContainer.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        middleButtonContainer.topAnchor.constraint(equalTo: topAnchor).isActive = true
        middleButtonContainer.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc fileprivate func didPressSingleCharacterKey(_ button: KeyboardButton) {
        guard let text = button.currentTitle else { return }
        UIDevice.current.playInputClick()
        textView?.insertText(text)
    }
    
    @objc fileprivate func didTapSmilieButton() {
        UIDevice.current.playInputClick()
        smilieCommand.execute()
    }
    
    @objc fileprivate func didTapAutocloseButton() {
        UIDevice.current.playInputClick()
        autocloseCommand.execute()
    }
    
    fileprivate func updateColors() {
        let backgroundColor: UIColor
        let titleColor: UIColor
        let normalBackgroundColor: UIColor
        let selectedBackgroundColor: UIColor
        let shadowColor: UIColor
        
        switch keyboardAppearance {
        case .dark:
            backgroundColor = UIColor(white: 0.078, alpha: 1)
            titleColor = .white
            normalBackgroundColor = UIColor(white: 0.353, alpha: 1)
            selectedBackgroundColor = UIColor(white: 0.149, alpha: 1)
            shadowColor = .black
            
        default:
            switch traitCollection.userInterfaceIdiom {
            case .pad:
                backgroundColor = UIColor(red: 0.812, green: 0.824, blue: 0.835, alpha: 1)
            default:
                backgroundColor = UIColor(red: 0.863, green: 0.875, blue: 0.886, alpha: 1)
            }
            titleColor = .black
            normalBackgroundColor = UIColor(red: 0.988, green: 0.988, blue: 0.992, alpha: 1)
            selectedBackgroundColor = UIColor(red: 0.831, green: 0.839, blue: 0.847, alpha: 1)
            shadowColor = .gray
        }
        
        self.backgroundColor = backgroundColor
        
        for button in [smilieButton, autocloseButton] + middleButtons {
            button.setTitleColor(titleColor, for: UIControlState())
            button.normalBackgroundColor = normalBackgroundColor
            button.selectedBackgroundColor = selectedBackgroundColor
            button.layer.shadowColor = shadowColor.cgColor
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom else { return }
        
        let width: CGFloat
        let height: CGFloat
        let edge: CGFloat
        let between: CGFloat
        switch traitCollection.userInterfaceIdiom {
        case .pad:
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom else { return }
        
        if traitCollection.userInterfaceIdiom == .phone {
            contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        } else {
            contentEdgeInsets = UIEdgeInsets()
        }
    }
}
