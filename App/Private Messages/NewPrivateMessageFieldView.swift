//  NewPrivateMessageFieldView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class NewPrivateMessageFieldView: UIView, AwfulComposeCustomView {
    let threadTagButton = AwfulThreadTagButton()
    let toField = ComposeField()
    let subjectField = ComposeField()
    private let topSeparator = UIView()
    private let bottomSeparator = UIView()
    
    var enabled = false {
        didSet {
            threadTagButton.enabled = enabled
            toField.textField.enabled = enabled
            subjectField.textField.enabled = enabled
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        threadTagButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(threadTagButton)
        
        toField.translatesAutoresizingMaskIntoConstraints = false
        toField.textField.autocapitalizationType = .None
        toField.textField.autocorrectionType = .No
        addSubview(toField)
        
        topSeparator.translatesAutoresizingMaskIntoConstraints = false
        topSeparator.backgroundColor = .lightGrayColor()
        addSubview(topSeparator)
        
        subjectField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subjectField)
        
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.backgroundColor = .lightGrayColor()
        addSubview(bottomSeparator)
        
        threadTagButton.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        toField.leadingAnchor.constraintEqualToAnchor(threadTagButton.trailingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(toField.trailingAnchor).active = true
        
        topSeparator.leadingAnchor.constraintEqualToAnchor(threadTagButton.trailingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(topSeparator.trailingAnchor).active = true
        
        subjectField.leadingAnchor.constraintEqualToAnchor(threadTagButton.trailingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(subjectField.trailingAnchor).active = true
        
        bottomSeparator.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(bottomSeparator.trailingAnchor).active = true
        
        toField.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        topSeparator.topAnchor.constraintEqualToAnchor(toField.bottomAnchor).active = true
        subjectField.topAnchor.constraintEqualToAnchor(topSeparator.bottomAnchor).active = true
        bottomSeparator.topAnchor.constraintEqualToAnchor(subjectField.bottomAnchor).active = true
        bottomAnchor.constraintEqualToAnchor(bottomSeparator.bottomAnchor).active = true
        
        toField.heightAnchor.constraintEqualToAnchor(subjectField.heightAnchor).active = true
        subjectField.heightAnchor.constraintEqualToAnchor(toField.heightAnchor).active = true
        topSeparator.heightAnchor.constraintEqualToConstant(1).active = true
        bottomSeparator.heightAnchor.constraintEqualToConstant(1).active = true
        
        threadTagButton.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true
        threadTagButton.widthAnchor.constraintEqualToConstant(54).active = true
        threadTagButton.widthAnchor.constraintEqualToAnchor(threadTagButton.heightAnchor).active = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var initialFirstResponder: UIResponder? {
        if toField.textField.text?.isEmpty ?? true {
            return toField.textField
        } else if subjectField.textField.text?.isEmpty ?? true {
            return subjectField.textField
        } else {
            return nil
        }
    }
}
