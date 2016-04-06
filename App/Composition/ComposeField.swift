//  ComposeField.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ComposeField: UIView {
    let label = UILabel()
    let textField = UITextField()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFontOfSize(16)
        label.setContentHuggingPriority(UILayoutPriorityDefaultHigh, forAxis: .Horizontal)
        label.setContentCompressionResistancePriority(UILayoutPriorityRequired, forAxis: .Horizontal)
        addSubview(label)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = UIFont.systemFontOfSize(16)
        addSubview(textField)
        
        label.leadingAnchor.constraintEqualToAnchor(leadingAnchor, constant: 4).active = true
        textField.leadingAnchor.constraintEqualToAnchor(label.trailingAnchor, constant: 8).active = true
        textField.trailingAnchor.constraintEqualToAnchor(trailingAnchor).active = true
        
        topAnchor.constraintEqualToAnchor(label.topAnchor).active = true
        label.bottomAnchor.constraintEqualToAnchor(bottomAnchor).active = true
        topAnchor.constraintEqualToAnchor(textField.topAnchor).active = true
        textField.bottomAnchor.constraintEqualToAnchor(bottomAnchor).active = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
