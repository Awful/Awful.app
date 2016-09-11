//  NewPrivateMessageFieldView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class NewPrivateMessageFieldView: UIView, ComposeCustomView {
    let threadTagButton = ThreadTagButton()
    let toField = ComposeField()
    let subjectField = ComposeField()
    fileprivate let topSeparator = UIView()
    fileprivate let bottomSeparator = UIView()
    
    var enabled = false {
        didSet {
            threadTagButton.isEnabled = enabled
            toField.textField.isEnabled = enabled
            subjectField.textField.isEnabled = enabled
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        threadTagButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(threadTagButton)
        
        toField.translatesAutoresizingMaskIntoConstraints = false
        toField.textField.autocapitalizationType = .none
        toField.textField.autocorrectionType = .no
        addSubview(toField)
        
        topSeparator.translatesAutoresizingMaskIntoConstraints = false
        topSeparator.backgroundColor = .lightGray
        addSubview(topSeparator)
        
        subjectField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subjectField)
        
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.backgroundColor = .lightGray
        addSubview(bottomSeparator)
        
        threadTagButton.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        toField.leadingAnchor.constraint(equalTo: threadTagButton.trailingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: toField.trailingAnchor).isActive = true
        
        topSeparator.leadingAnchor.constraint(equalTo: threadTagButton.trailingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: topSeparator.trailingAnchor).isActive = true
        
        subjectField.leadingAnchor.constraint(equalTo: threadTagButton.trailingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: subjectField.trailingAnchor).isActive = true
        
        bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: bottomSeparator.trailingAnchor).isActive = true
        
        toField.topAnchor.constraint(equalTo: topAnchor).isActive = true
        topSeparator.topAnchor.constraint(equalTo: toField.bottomAnchor).isActive = true
        subjectField.topAnchor.constraint(equalTo: topSeparator.bottomAnchor).isActive = true
        bottomSeparator.topAnchor.constraint(equalTo: subjectField.bottomAnchor).isActive = true
        bottomAnchor.constraint(equalTo: bottomSeparator.bottomAnchor).isActive = true
        
        toField.heightAnchor.constraint(equalTo: subjectField.heightAnchor).isActive = true
        subjectField.heightAnchor.constraint(equalTo: toField.heightAnchor).isActive = true
        topSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        bottomSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        threadTagButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        threadTagButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        threadTagButton.widthAnchor.constraint(equalTo: threadTagButton.heightAnchor).isActive = true
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
