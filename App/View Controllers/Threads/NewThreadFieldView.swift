//  NewThreadFieldView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class NewThreadFieldView: UIView, ComposeCustomView {
    let threadTagButton = ThreadTagButton()
    let subjectField = ComposeField()
    fileprivate let separator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        threadTagButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(threadTagButton)
        
        subjectField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subjectField)
        
        separator.backgroundColor = .lightGray
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        
        threadTagButton.widthAnchor.constraint(equalTo: threadTagButton.heightAnchor).isActive = true
        
        threadTagButton.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        subjectField.leadingAnchor.constraint(equalTo: threadTagButton.trailingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: subjectField.trailingAnchor).isActive = true
        
        separator.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: separator.trailingAnchor).isActive = true
        
        threadTagButton.topAnchor.constraint(equalTo: topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: threadTagButton.bottomAnchor).isActive = true
        
        subjectField.topAnchor.constraint(equalTo: topAnchor).isActive = true
        separator.topAnchor.constraint(equalTo: subjectField.bottomAnchor).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        bottomAnchor.constraint(equalTo: separator.bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var enabled = false {
        didSet {
            threadTagButton.isEnabled = enabled
            subjectField.textField.isEnabled = enabled
        }
    }
    
    var initialFirstResponder: UIResponder? {
        if subjectField.textField.text?.isEmpty == false {
            return subjectField.textField
        }
        return nil
    }
}
