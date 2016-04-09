//  NewThreadFieldView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class NewThreadFieldView: UIView, AwfulComposeCustomView {
    let threadTagButton = ThreadTagButton()
    let subjectField = ComposeField()
    private let separator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        threadTagButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(threadTagButton)
        
        subjectField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subjectField)
        
        separator.backgroundColor = .lightGrayColor()
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        
        threadTagButton.widthAnchor.constraintEqualToAnchor(threadTagButton.heightAnchor).active = true
        
        threadTagButton.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        subjectField.leadingAnchor.constraintEqualToAnchor(threadTagButton.trailingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(subjectField.trailingAnchor).active = true
        
        separator.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        trailingAnchor.constraintEqualToAnchor(separator.trailingAnchor).active = true
        
        threadTagButton.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        bottomAnchor.constraintEqualToAnchor(threadTagButton.bottomAnchor).active = true
        
        subjectField.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        separator.topAnchor.constraintEqualToAnchor(subjectField.bottomAnchor).active = true
        separator.heightAnchor.constraintEqualToConstant(1).active = true
        bottomAnchor.constraintEqualToAnchor(separator.bottomAnchor).active = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var enabled = false {
        didSet {
            threadTagButton.enabled = enabled
            subjectField.textField.enabled = enabled
        }
    }
    
    var initialFirstResponder: UIResponder? {
        if subjectField.textField.text?.isEmpty == false {
            return subjectField.textField
        }
        return nil
    }
}
