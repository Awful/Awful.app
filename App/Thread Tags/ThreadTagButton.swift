//  ThreadTagButton.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ThreadTagButton: UIButton {
    private let secondaryTagImageView = UIImageView()
    var secondaryTagImage: UIImage? {
        get { return secondaryTagImageView.image }
        set {
            if let
                image = newValue,
                cgimage = image.CGImage
            {
                secondaryTagImageView.image = UIImage(CGImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
            } else {
                secondaryTagImageView.image = newValue
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secondaryTagImageView)
        
        trailingAnchor.constraintEqualToAnchor(secondaryTagImageView.trailingAnchor).active = true
        bottomAnchor.constraintEqualToAnchor(secondaryTagImageView.bottomAnchor).active = true
    }
}
