//  ThreadTagButton.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class ThreadTagButton: UIButton {
    fileprivate let secondaryTagImageView = UIImageView()
    var secondaryTagImage: UIImage? {
        get { return secondaryTagImageView.image }
        set {
            if let
                image = newValue,
                let cgimage = image.cgImage
            {
                secondaryTagImageView.image = UIImage(cgImage: cgimage, scale: image.scale, orientation: image.imageOrientation)
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
    
    fileprivate func commonInit() {
        secondaryTagImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secondaryTagImageView)
        
        trailingAnchor.constraint(equalTo: secondaryTagImageView.trailingAnchor).isActive = true
        bottomAnchor.constraint(equalTo: secondaryTagImageView.bottomAnchor).isActive = true
    }
}
